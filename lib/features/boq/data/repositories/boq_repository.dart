import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';
import '../models/boq_header_model.dart';
import '../models/boq_item_model.dart';
import '../models/boq_vs_actual_row.dart';

/// All Supabase access for the BOQ / Estimation module lives here.
///
/// RLS (migration 055) scopes every read/write to the caller's company, so the
/// repository never has to add company filters on reads. Writes must still send
/// `company_id` to satisfy the policy WITH CHECK clause.
class BoqRepository {
  final SupabaseClient _client;

  BoqRepository({SupabaseClient? client}) : _client = client ?? supabase;

  // ── Headers ────────────────────────────────────────────────────────

  /// All BOQ headers for a project, newest first. Each header is enriched with
  /// a [BoqHeaderModel.total] rolled up from its line items.
  Future<List<BoqHeaderModel>> getHeadersForProject(String projectId) async {
    final rows = await _client
        .from('boq_headers')
        .select('*, boq_items(amount)')
        .eq('project_id', projectId)
        .order('created_at', ascending: false);

    return (rows as List).map((raw) {
      final json = Map<String, dynamic>.from(raw as Map);
      final items = (json['boq_items'] as List?) ?? const [];
      final total = items.fold<double>(
        0,
        (sum, e) => sum + ((e as Map)['amount'] as num? ?? 0).toDouble(),
      );
      json.remove('boq_items');
      return BoqHeaderModel.fromJson(json).copyWith(total: total);
    }).toList();
  }

  /// A single header by id (without items).
  Future<BoqHeaderModel> getHeader(String boqId) async {
    final row =
        await _client.from('boq_headers').select().eq('id', boqId).single();
    return BoqHeaderModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Create a header. [companyId] and [createdBy] come from the auth layer.
  Future<BoqHeaderModel> createHeader({
    required String companyId,
    required String projectId,
    required String name,
    String version = 'v1',
    String? notes,
    String? createdBy,
  }) async {
    final draft = BoqHeaderModel(
      id: '',
      companyId: companyId,
      projectId: projectId,
      name: name,
      version: version,
      notes: notes,
      createdBy: createdBy,
    );
    final row = await _client
        .from('boq_headers')
        .insert(draft.toInsertJson())
        .select()
        .single();
    return BoqHeaderModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteHeader(String boqId) async {
    await _client.from('boq_headers').delete().eq('id', boqId);
  }

  // ── Items ──────────────────────────────────────────────────────────

  /// All line items for a BOQ, ordered by category then sort order.
  Future<List<BoqItemModel>> getItems(String boqId) async {
    final rows = await _client
        .from('boq_items')
        .select()
        .eq('boq_id', boqId)
        .order('category', ascending: true)
        .order('sort_order', ascending: true);

    return (rows as List)
        .map((e) => BoqItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Add a line item. `amount` is GENERATED in Postgres, so it is read back
  /// from the inserted row.
  Future<BoqItemModel> addItem({
    required String companyId,
    required String boqId,
    required String category,
    required String description,
    required String unit,
    required double qty,
    required double rate,
    int sortOrder = 0,
  }) async {
    final draft = BoqItemModel(
      id: '',
      companyId: companyId,
      boqId: boqId,
      category: category,
      description: description,
      unit: unit,
      qty: qty,
      rate: rate,
      sortOrder: sortOrder,
    );
    final row = await _client
        .from('boq_items')
        .insert(draft.toInsertJson())
        .select()
        .single();
    return BoqItemModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteItem(String itemId) async {
    await _client.from('boq_items').delete().eq('id', itemId);
  }

  // ── BOQ vs Actual ──────────────────────────────────────────────────

  /// Compares a BOQ's estimate (by category) against actual material
  /// consumption for its project.
  ///
  /// Estimate: sum of `boq_items.amount` / `qty`, grouped by category.
  /// Actual: outward `material_logs` (consumption) for the project, joined to
  /// `stock_items` for the item's category and unit_price. Categories present
  /// only in actuals are appended with a null estimate.
  Future<List<BoqVsActualRow>> getBoqVsActual({
    required String boqId,
    required String projectId,
  }) async {
    // 1. Estimate side — group BOQ items by category.
    final items = await getItems(boqId);
    final estByCat = <String, _Agg>{};
    for (final item in items) {
      final cat = item.category.trim().isEmpty ? 'General' : item.category.trim();
      final agg = estByCat.putIfAbsent(cat, () => _Agg());
      agg.qty += item.qty;
      agg.amount += item.computedAmount;
    }

    // 2. Actual side — outward consumption logs joined to stock_items.
    //    If the source is unavailable/empty this stays empty and the UI shows
    //    estimate-only rows with a TODO note.
    final actualByCat = <String, _Agg>{};
    try {
      final logs = await _client
          .from('material_logs')
          .select('quantity, stock_items(category, unit_price)')
          .eq('project_id', projectId)
          .eq('log_type', 'outward');

      for (final raw in (logs as List)) {
        final json = Map<String, dynamic>.from(raw as Map);
        final stock = json['stock_items'];
        final stockMap =
            stock is Map ? Map<String, dynamic>.from(stock) : const {};
        final cat = (stockMap['category'] as String?)?.trim();
        final category = (cat == null || cat.isEmpty) ? 'Uncategorized' : cat;
        final qty = (json['quantity'] as num?)?.toDouble() ?? 0;
        final unitPrice = (stockMap['unit_price'] as num?)?.toDouble() ?? 0;
        final agg = actualByCat.putIfAbsent(category, () => _Agg());
        agg.qty += qty;
        agg.amount += qty * unitPrice;
      }
    } catch (_) {
      // Actual source unresolved — leave actualByCat empty (rows show TODO).
    }

    // 3. Merge: every category from either side, estimate then actual.
    final categories = <String>{...estByCat.keys, ...actualByCat.keys}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return categories.map((cat) {
      final est = estByCat[cat];
      final act = actualByCat[cat];
      return BoqVsActualRow(
        category: cat,
        estimateAmount: est?.amount ?? 0,
        estimateQty: est?.qty ?? 0,
        actualQty: act?.qty,
        actualAmount: act?.amount,
      );
    }).toList();
  }
}

class _Agg {
  double qty = 0;
  double amount = 0;
}

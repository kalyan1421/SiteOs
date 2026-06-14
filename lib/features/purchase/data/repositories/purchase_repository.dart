import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';
import '../models/purchase_indent.dart';
import '../models/purchase_order.dart';

/// Repository for the Purchase Order Workflow (AKS-83).
///
/// All Supabase access for indents, POs and their line items lives here.
/// Tables are tenant-scoped via RLS (`company_id = current_company_id()`),
/// so reads are automatically filtered; writes must stamp `company_id`.
class PurchaseRepository {
  final SupabaseClient _client;

  PurchaseRepository({SupabaseClient? client}) : _client = client ?? supabase;

  // ============================================================
  // PURCHASE INDENTS
  // ============================================================

  /// List indents (newest first), with their line items eager-loaded.
  Future<List<PurchaseIndent>> getIndents({String? projectId}) async {
    var query = _client
        .from('purchase_indents')
        .select('*, indent_items(*)');
    if (projectId != null) {
      query = query.eq('project_id', projectId);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => PurchaseIndent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single indent with items.
  Future<PurchaseIndent> getIndent(String id) async {
    final row = await _client
        .from('purchase_indents')
        .select('*, indent_items(*)')
        .eq('id', id)
        .single();
    return PurchaseIndent.fromJson(row);
  }

  /// Create an indent header + its items in the caller's company.
  /// Returns the created indent (with items).
  Future<PurchaseIndent> createIndent(
    PurchaseIndent indent,
    List<IndentItem> items,
  ) async {
    final companyId = await _requireCompanyId();
    final userId = _client.auth.currentUser?.id;

    final headerPayload = {
      ...indent.toJson(),
      'company_id': companyId,
      'requested_by': indent.requestedBy ?? userId,
    };

    final created = await _client
        .from('purchase_indents')
        .insert(headerPayload)
        .select()
        .single();
    final indentId = created['id'] as String;

    if (items.isNotEmpty) {
      final itemRows = items
          .map((i) => {
                ...i.toInsertJson(),
                'company_id': companyId,
                'indent_id': indentId,
              })
          .toList();
      await _client.from('indent_items').insert(itemRows);
    }

    return getIndent(indentId);
  }

  /// Update an indent's status (e.g. submit / approve / reject / close).
  Future<void> updateIndentStatus(String id, IndentStatus status) async {
    await _client
        .from('purchase_indents')
        .update({'status': status.key}).eq('id', id);
  }

  /// Delete an indent (line items cascade in the DB).
  Future<void> deleteIndent(String id) async {
    await _client.from('purchase_indents').delete().eq('id', id);
  }

  // ============================================================
  // PURCHASE ORDERS
  // ============================================================

  /// List POs (newest first), with their line items eager-loaded.
  Future<List<PurchaseOrder>> getPurchaseOrders({
    String? supplierId,
    PoStatus? status,
  }) async {
    var query =
        _client.from('purchase_orders').select('*, po_items(*)');
    if (supplierId != null) {
      query = query.eq('supplier_id', supplierId);
    }
    if (status != null) {
      query = query.eq('status', status.key);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single PO with items.
  Future<PurchaseOrder> getPurchaseOrder(String id) async {
    final row = await _client
        .from('purchase_orders')
        .select('*, po_items(*)')
        .eq('id', id)
        .single();
    return PurchaseOrder.fromJson(row);
  }

  /// Create a PO header + items. Total is derived from item amounts.
  Future<PurchaseOrder> createPurchaseOrder(
    PurchaseOrder po,
    List<PoItem> items,
  ) async {
    final companyId = await _requireCompanyId();
    final userId = _client.auth.currentUser?.id;
    final total = items.fold<double>(0, (sum, i) => sum + i.amount);

    final headerPayload = {
      ...po.toJson(),
      'company_id': companyId,
      'total': total,
      'created_by': po.createdBy ?? userId,
    };

    final created = await _client
        .from('purchase_orders')
        .insert(headerPayload)
        .select()
        .single();
    final poId = created['id'] as String;

    if (items.isNotEmpty) {
      final itemRows = items
          .map((i) => {
                ...i.toInsertJson(),
                'company_id': companyId,
                'po_id': poId,
              })
          .toList();
      await _client.from('po_items').insert(itemRows);
    }

    return getPurchaseOrder(poId);
  }

  /// Update a PO's status.
  Future<void> updatePoStatus(String id, PoStatus status) async {
    await _client
        .from('purchase_orders')
        .update({'status': status.key}).eq('id', id);
  }

  /// Delete a PO (line items cascade in the DB).
  Future<void> deletePurchaseOrder(String id) async {
    await _client.from('purchase_orders').delete().eq('id', id);
  }

  // ============================================================
  // 3-WAY GRN MATCH
  // ============================================================

  /// Persist received quantities for a PO's line items (the GRN side of the
  /// 3-way match), then mark the PO 'received' when every line matches.
  ///
  /// [receivedByItemId] maps po_items.id -> received qty.
  Future<PurchaseOrder> recordGrnMatch(
    String poId,
    Map<String, double> receivedByItemId,
  ) async {
    for (final entry in receivedByItemId.entries) {
      await _client
          .from('po_items')
          .update({'received_qty': entry.value}).eq('id', entry.key);
    }

    final updated = await getPurchaseOrder(poId);
    if (updated.isFullyMatched && updated.status != PoStatus.received) {
      await updatePoStatus(poId, PoStatus.received);
      return getPurchaseOrder(poId);
    }
    return updated;
  }

  // ============================================================
  // LOOKUPS (read-only, for PO form dropdowns)
  // ============================================================

  /// Active suppliers (id + name) for the supplier picker on the PO form.
  /// Reads the shared `suppliers` table read-only; returns [] on any error so
  /// the form still works when the suppliers module is absent.
  Future<List<({String id, String name})>> getSupplierOptions() async {
    try {
      final rows = await _client
          .from('suppliers')
          .select('id, name')
          .order('name', ascending: true);
      return (rows as List)
          .map((e) => (
                id: (e as Map<String, dynamic>)['id'] as String,
                name: e['name'] as String? ?? 'Unnamed',
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Resolve the caller's company_id (required to stamp tenant rows).
  Future<String> _requireCompanyId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated — cannot resolve company.');
    }
    final row = await _client
        .from('user_profiles')
        .select('company_id')
        .eq('id', userId)
        .single();
    final companyId = row['company_id'] as String?;
    if (companyId == null) {
      throw StateError('User has no company_id — cannot create purchase rows.');
    }
    return companyId;
  }
}

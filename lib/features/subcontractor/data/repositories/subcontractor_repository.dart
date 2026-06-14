import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';
import '../models/subcontractor_model.dart';
import '../models/work_order_model.dart';
import '../models/sub_ra_bill_model.dart';

/// All Supabase access for the subcontractor module. Screens never call
/// Supabase directly — they go through this repository.
///
/// Every write stamps `company_id` so RLS (migration 062) accepts it; reads
/// are already tenant-filtered by the `*_tenant_access` policies.
class SubcontractorRepository {
  final SupabaseClient _client;

  SubcontractorRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  // ── Subcontractors ────────────────────────────────────────────────

  Future<List<SubcontractorModel>> getSubcontractors({String? search}) async {
    var query = _client.from('subcontractors').select();
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('name', '%${search.trim()}%');
    }
    final rows = await query.order('name');
    return (rows as List)
        .map((e) => SubcontractorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubcontractorModel> getSubcontractor(String id) async {
    final row =
        await _client.from('subcontractors').select().eq('id', id).single();
    return SubcontractorModel.fromJson(row);
  }

  Future<SubcontractorModel> createSubcontractor({
    required String companyId,
    required String name,
    String? gstin,
    String? pan,
    String? specialization,
    String? phone,
    String? email,
    String? address,
  }) async {
    final payload = SubcontractorModel(
      id: '',
      companyId: companyId,
      name: name.trim(),
      gstin: _nullIfBlank(gstin),
      pan: _nullIfBlank(pan),
      specialization: _nullIfBlank(specialization),
      phone: _nullIfBlank(phone),
      email: _nullIfBlank(email),
      address: _nullIfBlank(address),
    ).toJson();

    final row =
        await _client.from('subcontractors').insert(payload).select().single();
    return SubcontractorModel.fromJson(row);
  }

  Future<SubcontractorModel> updateSubcontractor(
    SubcontractorModel subcontractor,
  ) async {
    final row = await _client
        .from('subcontractors')
        .update(subcontractor.toJson())
        .eq('id', subcontractor.id)
        .select()
        .single();
    return SubcontractorModel.fromJson(row);
  }

  Future<void> deleteSubcontractor(String id) async {
    await _client.from('subcontractors').delete().eq('id', id);
  }

  // ── Work orders ───────────────────────────────────────────────────

  static const _woSelect =
      '*, subcontractors(name), projects(name)';

  Future<List<WorkOrderModel>> getWorkOrders({
    String? subcontractorId,
  }) async {
    var query = _client.from('work_orders').select(_woSelect);
    if (subcontractorId != null) {
      query = query.eq('subcontractor_id', subcontractorId);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => WorkOrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkOrderModel> getWorkOrder(String id) async {
    final row =
        await _client.from('work_orders').select(_woSelect).eq('id', id).single();
    return WorkOrderModel.fromJson(row);
  }

  Future<WorkOrderModel> createWorkOrder({
    required String companyId,
    required String subcontractorId,
    String? projectId,
    String? woNumber,
    required String scope,
    required double value,
    double retentionPct = 0,
    double tdsPct = 0,
    WorkOrderStatus status = WorkOrderStatus.active,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
  }) async {
    final payload = WorkOrderModel(
      id: '',
      companyId: companyId,
      subcontractorId: subcontractorId,
      projectId: projectId,
      woNumber: _nullIfBlank(woNumber),
      scope: scope.trim(),
      value: value,
      retentionPct: retentionPct,
      tdsPct: tdsPct,
      status: status,
      startDate: startDate,
      endDate: endDate,
      notes: _nullIfBlank(notes),
    ).toJson();

    final row = await _client
        .from('work_orders')
        .insert(payload)
        .select(_woSelect)
        .single();
    return WorkOrderModel.fromJson(row);
  }

  Future<WorkOrderModel> updateWorkOrder(WorkOrderModel workOrder) async {
    final row = await _client
        .from('work_orders')
        .update(workOrder.toJson())
        .eq('id', workOrder.id)
        .select(_woSelect)
        .single();
    return WorkOrderModel.fromJson(row);
  }

  Future<void> deleteWorkOrder(String id) async {
    await _client.from('work_orders').delete().eq('id', id);
  }

  // ── Projects (read-only lookup for the WO form) ───────────────────

  /// Minimal {id, name} list of the tenant's projects, used to populate the
  /// project dropdown on the work-order form. RLS on `projects` already scopes
  /// this to the caller's company.
  Future<List<({String id, String name})>> getProjectOptions() async {
    final rows =
        await _client.from('projects').select('id, name').order('name');
    return (rows as List)
        .map((e) => (
              id: e['id'] as String,
              name: (e['name'] as String?) ?? 'Untitled',
            ))
        .toList();
  }

  // ── Sub RA bills ──────────────────────────────────────────────────

  Future<List<SubRaBillModel>> getRaBills(String workOrderId) async {
    final rows = await _client
        .from('sub_ra_bills')
        .select()
        .eq('work_order_id', workOrderId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => SubRaBillModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubRaBillModel> createRaBill({
    required String companyId,
    required String workOrderId,
    required String number,
    required double value,
    required double tdsPct,
    required double retentionPct,
    DateTime? billDate,
    SubRaBillStatus status = SubRaBillStatus.draft,
    String? notes,
  }) async {
    // Recompute deductions server-side-of-client so the persisted columns are
    // always internally consistent regardless of what the UI sent.
    final c = SubRaBillModel.calc(
      value: value,
      tdsPct: tdsPct,
      retentionPct: retentionPct,
    );

    final payload = SubRaBillModel(
      id: '',
      companyId: companyId,
      workOrderId: workOrderId,
      number: number.trim(),
      value: value,
      tdsPct: tdsPct,
      tds: c.tds,
      retentionPct: retentionPct,
      retention: c.retention,
      net: c.net,
      billDate: billDate,
      status: status,
      notes: _nullIfBlank(notes),
    ).toJson();

    final row =
        await _client.from('sub_ra_bills').insert(payload).select().single();
    return SubRaBillModel.fromJson(row);
  }

  Future<SubRaBillModel> updateRaBillStatus(
    String id,
    SubRaBillStatus status,
  ) async {
    final row = await _client
        .from('sub_ra_bills')
        .update({'status': status.value})
        .eq('id', id)
        .select()
        .single();
    return SubRaBillModel.fromJson(row);
  }

  Future<void> deleteRaBill(String id) async {
    await _client.from('sub_ra_bills').delete().eq('id', id);
  }

  static String? _nullIfBlank(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}

import '../../../../core/config/supabase_client.dart';
import '../gst_calculator.dart';
import '../models/client.dart';
import '../models/gst_config.dart';
import '../models/project_contract.dart';
import '../models/ra_bill.dart';

/// All Supabase access for the GST / RA-billing module. Screens never call
/// `supabase` directly — they go through this repository.
///
/// RLS (migration 056) already scopes every row to the caller's company via
/// `company_id = current_company_id()`, but we also stamp `company_id` on
/// inserts so rows are well-formed and `WITH CHECK` passes.
class RaBillingRepository {
  // ── company_gst_config ────────────────────────────────────────────

  /// The single GST config row for [companyId], or null if not set up yet.
  Future<GstConfig?> fetchGstConfig(String companyId) async {
    final rows = await supabase
        .from('company_gst_config')
        .select()
        .eq('company_id', companyId)
        .limit(1);
    if (rows.isEmpty) return null;
    return GstConfig.fromJson(rows.first);
  }

  /// Insert or update the company's GST config (one row per company).
  Future<GstConfig> upsertGstConfig({
    required String companyId,
    required GstConfig config,
  }) async {
    final payload = {
      ...config.toJson(),
      'company_id': companyId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final row = await supabase
        .from('company_gst_config')
        .upsert(payload, onConflict: 'company_id')
        .select()
        .single();
    return GstConfig.fromJson(row);
  }

  // ── clients ────────────────────────────────────────────────────────

  Future<List<BillingClient>> fetchClients(String companyId) async {
    final rows = await supabase
        .from('clients')
        .select()
        .eq('company_id', companyId)
        .order('name');
    return rows.map<BillingClient>((r) => BillingClient.fromJson(r)).toList();
  }

  Future<BillingClient> createClient({
    required String companyId,
    required BillingClient client,
  }) async {
    final payload = {...client.toJson(), 'company_id': companyId};
    final row =
        await supabase.from('clients').insert(payload).select().single();
    return BillingClient.fromJson(row);
  }

  Future<BillingClient> updateClient({
    required String id,
    required BillingClient client,
  }) async {
    final payload = {
      ...client.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    final row = await supabase
        .from('clients')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return BillingClient.fromJson(row);
  }

  Future<void> deleteClient(String id) async {
    await supabase.from('clients').delete().eq('id', id);
  }

  // ── project_contracts ──────────────────────────────────────────────

  Future<List<ProjectContract>> fetchContracts(String companyId) async {
    final rows = await supabase
        .from('project_contracts')
        .select('*, clients(name, state_code)')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return rows
        .map<ProjectContract>((r) => ProjectContract.fromJson(r))
        .toList();
  }

  Future<ProjectContract?> fetchContract(String id) async {
    final rows = await supabase
        .from('project_contracts')
        .select('*, clients(name, state_code)')
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return ProjectContract.fromJson(rows.first);
  }

  Future<ProjectContract> createContract({
    required String companyId,
    required ProjectContract contract,
  }) async {
    final payload = {...contract.toJson(), 'company_id': companyId};
    final row = await supabase
        .from('project_contracts')
        .insert(payload)
        .select('*, clients(name, state_code)')
        .single();
    return ProjectContract.fromJson(row);
  }

  Future<ProjectContract> updateContract({
    required String id,
    required ProjectContract contract,
  }) async {
    final payload = {
      ...contract.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    final row = await supabase
        .from('project_contracts')
        .update(payload)
        .eq('id', id)
        .select('*, clients(name, state_code)')
        .single();
    return ProjectContract.fromJson(row);
  }

  Future<void> deleteContract(String id) async {
    await supabase.from('project_contracts').delete().eq('id', id);
  }

  // ── ra_bills ───────────────────────────────────────────────────────

  static const String _billSelect =
      '*, project_contracts(name, clients(name))';

  Future<List<RaBill>> fetchBills(String companyId) async {
    final rows = await supabase
        .from('ra_bills')
        .select(_billSelect)
        .eq('company_id', companyId)
        .order('bill_date', ascending: false);
    return rows.map<RaBill>((r) => RaBill.fromJson(r)).toList();
  }

  Future<List<RaBill>> fetchBillsForContract(String contractId) async {
    final rows = await supabase
        .from('ra_bills')
        .select(_billSelect)
        .eq('contract_id', contractId)
        .order('bill_date', ascending: false);
    return rows.map<RaBill>((r) => RaBill.fromJson(r)).toList();
  }

  Future<RaBill?> fetchBill(String id) async {
    final rows =
        await supabase.from('ra_bills').select(_billSelect).eq('id', id).limit(1);
    if (rows.isEmpty) return null;
    return RaBill.fromJson(rows.first);
  }

  /// The highest cumulative work done recorded so far on a contract — used as
  /// the "previous work done" baseline for the next RA bill.
  Future<double> latestCumulativeForContract(String contractId) async {
    final rows = await supabase
        .from('ra_bills')
        .select('cumulative_work_done')
        .eq('contract_id', contractId)
        .order('cumulative_work_done', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows.first['cumulative_work_done'] as num?)?.toDouble() ?? 0;
  }

  /// Total advance already recovered on a contract (to cap further recovery).
  Future<double> totalAdvanceRecovered(String contractId) async {
    final rows = await supabase
        .from('ra_bills')
        .select('advance_recovery')
        .eq('contract_id', contractId);
    var sum = 0.0;
    for (final r in rows) {
      sum += (r['advance_recovery'] as num?)?.toDouble() ?? 0;
    }
    return GstCalculator.round2(sum);
  }

  /// Next sequential bill number for a contract, e.g. "RA-3".
  Future<String> nextBillNumber(String contractId) async {
    final rows = await supabase
        .from('ra_bills')
        .select('id')
        .eq('contract_id', contractId);
    return 'RA-${rows.length + 1}';
  }

  Future<RaBill> createBill({
    required String companyId,
    required RaBill bill,
  }) async {
    final payload = {...bill.toJson(), 'company_id': companyId};
    final row = await supabase
        .from('ra_bills')
        .insert(payload)
        .select(_billSelect)
        .single();
    return RaBill.fromJson(row);
  }

  Future<RaBill> updateBillStatus({
    required String id,
    required RaBillStatus status,
  }) async {
    final row = await supabase
        .from('ra_bills')
        .update({
          'status': status.value,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select(_billSelect)
        .single();
    return RaBill.fromJson(row);
  }

  Future<void> deleteBill(String id) async {
    await supabase.from('ra_bills').delete().eq('id', id);
  }
}

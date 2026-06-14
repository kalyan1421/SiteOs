import '../../../../core/config/supabase_client.dart';

/// Company (tenant) data access. Backed by the `companies` table and the
/// `register_company` RPC (migrations 052 + 053).
class CompanyRepository {
  /// Atomically create the caller's company and promote them to company admin.
  /// Must be called while authenticated (right after sign-up). Returns the new
  /// company id.
  Future<String> registerCompany({
    required String name,
    String? gstin,
    String? fullName,
  }) async {
    final id = await supabase.rpc(
      'register_company',
      params: {
        'p_name': name,
        'p_gstin': gstin,
        'p_full_name': fullName,
      },
    );
    return id as String;
  }

  /// Fetch the current user's company row (RLS scopes it to their tenant).
  Future<Map<String, dynamic>?> getCompany(String companyId) {
    return supabase
        .from('companies')
        .select()
        .eq('id', companyId)
        .maybeSingle();
  }
}

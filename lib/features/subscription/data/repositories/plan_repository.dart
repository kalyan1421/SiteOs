import '../../../../core/config/supabase_client.dart';
import '../models/plan.dart';

/// Reads a company's plan and the matching `plan_features` row.
///
/// Both tables are protected by RLS (migration 052): `companies` is readable
/// only by its members, `plan_features` by any authenticated user.
class PlanRepository {
  /// Resolve the active [PlanFeatures] for [companyId]. Falls back to a locked
  /// trial feature set if the company or the lookup row can't be read.
  Future<PlanFeatures> fetchForCompany(String companyId) async {
    try {
      final company = await supabase
          .from('companies')
          .select('plan, sub_status, trial_ends_at')
          .eq('id', companyId)
          .maybeSingle();

      final plan = SiteOsPlan.fromKey(company?['plan'] as String?);

      final row = await supabase
          .from('plan_features')
          .select()
          .eq('plan', plan.key)
          .maybeSingle();

      if (row == null) return PlanFeatures.fallback(plan);
      return PlanFeatures.fromJson({
        ...row,
        'plan': plan.key,
        'sub_status': company?['sub_status'],
        'trial_ends_at': company?['trial_ends_at'],
      });
    } catch (e) {
      logger.w('PlanRepository.fetchForCompany failed: $e');
      return PlanFeatures.fallback(SiteOsPlan.trial);
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/plan.dart';
import '../data/repositories/plan_repository.dart';

final planRepositoryProvider = Provider<PlanRepository>((ref) => PlanRepository());

/// The current company's resolved plan features. Re-fetches whenever the
/// signed-in profile (and thus `companyId`) changes.
final planFeaturesProvider = FutureProvider<PlanFeatures>((ref) async {
  final companyId = ref.watch(userProfileProvider)?.companyId;
  if (companyId == null) return PlanFeatures.fallback(SiteOsPlan.trial);
  return ref.watch(planRepositoryProvider).fetchForCompany(companyId);
});

/// Whether [feature] is unlocked for the current plan. Returns false while
/// loading or on error (fail closed).
final planGuardProvider = Provider.family<bool, AppFeature>((ref, feature) {
  return ref.watch(planFeaturesProvider).maybeWhen(
        data: (features) => features.has(feature),
        orElse: () => false,
      );
});

/// The current plan tier (defaults to Trial while loading / unknown).
final currentPlanProvider = Provider<SiteOsPlan>((ref) {
  return ref.watch(planFeaturesProvider).maybeWhen(
        data: (features) => features.plan,
        orElse: () => SiteOsPlan.trial,
      );
});

/// True when the company's trial or subscription has expired.
/// Returns false while loading (never block the user prematurely).
final isSubscriptionExpiredProvider = Provider<bool>((ref) {
  return ref.watch(planFeaturesProvider).maybeWhen(
        data: (features) => features.isExpired,
        orElse: () => false,
      );
});

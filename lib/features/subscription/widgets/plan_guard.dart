import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/plan.dart';
import '../providers/plan_provider.dart';

/// Wraps a premium screen. Renders [child] only when the current company's
/// plan unlocks [feature]; otherwise shows an [UpgradePaywall]. Never crashes —
/// shows a spinner while resolving the plan and a retry on error.
///
/// Usage (in app_router.dart, as a premium route is built):
/// ```dart
/// PlanGuard(feature: AppFeature.gstBilling, child: const GstBillingScreen())
/// ```
class PlanGuard extends ConsumerWidget {
  final AppFeature feature;
  final Widget child;

  /// Optional override for the upgrade CTA. Defaults to a "coming soon" notice
  /// until the plans/checkout screen ships (Linear AKS-66).
  final VoidCallback? onUpgrade;

  const PlanGuard({
    super.key,
    required this.feature,
    required this.child,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planFeaturesProvider);
    return plan.when(
      data: (features) => features.has(feature)
          ? child
          : UpgradePaywall(
              feature: feature,
              currentPlan: features.plan,
              onUpgrade: onUpgrade,
            ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _PlanError(
        onRetry: () => ref.invalidate(planFeaturesProvider),
      ),
    );
  }
}

/// Full-screen paywall shown when a feature is locked on the current plan.
class UpgradePaywall extends StatelessWidget {
  final AppFeature feature;
  final SiteOsPlan currentPlan;
  final VoidCallback? onUpgrade;

  const UpgradePaywall({
    super.key,
    required this.feature,
    required this.currentPlan,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final required = feature.requiredPlan;
    return Scaffold(
      appBar: AppBar(title: Text(feature.label)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.primary, size: 34),
                ),
                const SizedBox(height: AppSpacing.s5),
                Text(
                  '${feature.label} is a ${required.label} feature',
                  style: AppTextStyles.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  "You're on the ${currentPlan.label} plan. Upgrade to "
                  '${required.label} to unlock ${feature.label.toLowerCase()} '
                  'and more.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onUpgrade ?? () => _defaultUpgrade(context, required),
                    child: Text(
                      required.isCustomPriced
                          ? 'Talk to us'
                          : 'Upgrade to ${required.label} · ₹${required.monthlyPrice}/mo',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Maybe later'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _defaultUpgrade(BuildContext context, SiteOsPlan required) {
    // TODO(AKS-66): navigate to the Razorpay plans/checkout screen.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upgrade to ${required.label} — coming soon.')),
    );
  }
}

class _PlanError extends StatelessWidget {
  final VoidCallback onRetry;
  const _PlanError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.textHint, size: 40),
              const SizedBox(height: AppSpacing.s4),
              Text(
                "Couldn't verify your plan. Check your connection and try again.",
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s4),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

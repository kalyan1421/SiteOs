import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/plan.dart';
import '../providers/plan_provider.dart';

/// Subscription plans (AKS-66). Shows Starter / Professional / Enterprise
/// cards; tapping a paid plan opens the Razorpay checkout. The current plan is
/// badged and not purchasable again.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentPlan = ref.watch(currentPlanProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(l10n.subscriptionPlans),
        actions: [
          IconButton(
            tooltip: l10n.billingHistory,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () =>
                context.pushNamed(RouteNames.billingHistory),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.choosePlan, style: AppTextStyles.headlineSmall),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  l10n.choosePlanSubtitle,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s6),
                _PlanCard(
                  plan: SiteOsPlan.starter,
                  tagline: '5 projects · 10 users · WhatsApp reports',
                  features: const [
                    'Up to 5 projects',
                    'Up to 10 team members',
                    'Materials, labour & attendance',
                    'WhatsApp daily reports',
                  ],
                  currentPlan: currentPlan,
                ),
                const SizedBox(height: AppSpacing.s4),
                _PlanCard(
                  plan: SiteOsPlan.professional,
                  tagline: 'Everything, unlimited — for growing builders',
                  highlighted: true,
                  features: const [
                    'Unlimited projects & members',
                    'GST & RA billing + Tally export',
                    'BOQ & estimation',
                    'AI suite (OCR, reports, chat, BOQ)',
                    'Client portal',
                  ],
                  currentPlan: currentPlan,
                ),
                const SizedBox(height: AppSpacing.s4),
                _PlanCard(
                  plan: SiteOsPlan.enterprise,
                  tagline: 'Custom rollout, onboarding & SLAs',
                  features: const [
                    'Everything in Professional',
                    'Dedicated onboarding & support',
                    'Custom integrations',
                  ],
                  currentPlan: currentPlan,
                ),
                const SizedBox(height: AppSpacing.s5),
                Text(
                  l10n.billedMonthlyInr,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SiteOsPlan plan;
  final String tagline;
  final List<String> features;
  final bool highlighted;
  final SiteOsPlan currentPlan;

  const _PlanCard({
    required this.plan,
    required this.tagline,
    required this.features,
    required this.currentPlan,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCurrent = plan == currentPlan;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.border,
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted ? AppColors.elevatedShadow : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.label, style: AppTextStyles.titleLarge),
              const SizedBox(width: AppSpacing.s2),
              if (highlighted && !isCurrent)
                _Pill(text: l10n.mostPopular, color: AppColors.primary),
              if (isCurrent)
                _Pill(text: l10n.currentPlan, color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(tagline,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.s4),
          if (plan.isCustomPriced)
            Text(l10n.customPricing, style: AppTextStyles.headlineSmall)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('₹${plan.monthlyPrice}',
                    style: AppTextStyles.displaySmall),
                Text(' ${l10n.perMonth}',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          const SizedBox(height: AppSpacing.s4),
          for (final f in features) _FeatureRow(text: f),
          const SizedBox(height: AppSpacing.s5),
          SizedBox(
            width: double.infinity,
            child: isCurrent
                ? OutlinedButton(
                    onPressed: null,
                    child: Text(l10n.currentPlan),
                  )
                : FilledButton(
                    onPressed: () => _onSelect(context),
                    style: highlighted
                        ? null
                        : FilledButton.styleFrom(
                            backgroundColor: AppColors.primary),
                    child: Text(
                        plan.isCustomPriced ? l10n.talkToUs : l10n.subscribe),
                  ),
          ),
        ],
      ),
    );
  }

  void _onSelect(BuildContext context) {
    if (plan.isCustomPriced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.enterpriseContact)),
      );
      return;
    }
    context.pushNamed(
      RouteNames.subscriptionPayment,
      pathParameters: {'planKey': plan.key},
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.success),
          const SizedBox(width: AppSpacing.s2),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
            color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/plan.dart';
import '../providers/plan_provider.dart';

/// Shown when a company's 14-day trial has ended and no paid plan is active.
/// Offers an upgrade (Razorpay checkout lands in AKS-66) or sign out.
class TrialExpiredScreen extends ConsumerWidget {
  const TrialExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(currentPlanProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
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
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: const Icon(Icons.hourglass_bottom_rounded,
                        color: AppColors.warning, size: 34),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Text('Your free trial has ended',
                      style: AppTextStyles.headlineSmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'Upgrade to keep managing your sites — billing, materials, '
                    'labour, and reports, all in one place.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        // TODO(AKS-66): open the Razorpay plans/checkout screen.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Plans & checkout — coming soon.')),
                        );
                      },
                      child: Text(plan == SiteOsPlan.trial
                          ? 'See plans'
                          : 'Upgrade plan'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  TextButton(
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

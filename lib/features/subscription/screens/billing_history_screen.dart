import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/subscription.dart';
import '../providers/subscription_provider.dart';

/// Billing history — the list of paid invoices for the company (AKS-66).
/// Rows are sourced from `subscription_invoices`, written by the webhook.
class BillingHistoryScreen extends ConsumerWidget {
  const BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final invoices = ref.watch(invoicesProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: Text(l10n.billingHistory)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(invoicesProvider),
        child: invoices.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Empty(
            icon: Icons.wifi_off_rounded,
            title: l10n.somethingWentWrong,
            subtitle: l10n.pullToRetry,
          ),
          data: (list) {
            if (list.isEmpty) {
              return _Empty(
                icon: Icons.receipt_long_outlined,
                title: l10n.noInvoicesYet,
                subtitle: l10n.noInvoicesSubtitle,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.s3),
              itemBuilder: (_, i) => _InvoiceTile(invoice: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final SubscriptionInvoice invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final money = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final date = DateFormat.yMMMd().format(invoice.paidAt.toLocal());
    final paid = invoice.status == 'paid';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (paid ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              paid ? Icons.check_rounded : Icons.close_rounded,
              color: paid ? AppColors.success : AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: AppTextStyles.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  paid ? l10n.paid : invoice.status,
                  style: AppTextStyles.caption.copyWith(
                    color: paid ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          Text(money.format(invoice.amount), style: AppTextStyles.price),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView (not Column) so RefreshIndicator can always pull.
      padding: const EdgeInsets.all(AppSpacing.s8),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 44, color: AppColors.textHint),
        const SizedBox(height: AppSpacing.s4),
        Text(title,
            style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s2),
        Text(subtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ],
    );
  }
}

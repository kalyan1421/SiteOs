import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/client_bill.dart';
import '../providers/client_portal_providers.dart';
import '../widgets/client_state_views.dart';
import '../widgets/client_status_chip.dart';
import '../../../l10n/app_localizations.dart';

/// Read-only RA / progress bill status for an assigned project. Shows each
/// bill's title, amount, and status — no payment actions (clients are viewers).
class ClientBillingScreen extends ConsumerWidget {
  final String projectId;
  const ClientBillingScreen({super.key, required this.projectId});

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final billsAsync = ref.watch(clientBillsProvider(projectId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.billing)),
      body: billsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ClientErrorState(
          onRetry: () => ref.invalidate(clientBillsProvider(projectId)),
          message: "Couldn't load billing.",
        ),
        data: (bills) {
          // RA / progress bills only — exclude internal expense rows.
          final raBills = bills
              .where((b) => b.billType == 'invoice' || b.billType == 'income')
              .toList();
          if (raBills.isEmpty) {
            return const ClientEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No bills yet',
              message: 'Your RA / progress bills will appear here once raised.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(clientBillsProvider(projectId).future),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              children: [
                _SummaryCard(bills: raBills),
                const SizedBox(height: AppSpacing.s4),
                for (final bill in raBills) ...[
                  _BillCard(bill: bill),
                  const SizedBox(height: AppSpacing.s3),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<ClientBill> bills;
  const _SummaryCard({required this.bills});

  @override
  Widget build(BuildContext context) {
    num total = 0;
    num paid = 0;
    for (final b in bills) {
      total += b.amount;
      if (b.status == 'paid') paid += b.amount;
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Total billed',
              value: ClientBillingScreen._currency.format(total),
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          Expanded(
            child: _SummaryItem(
              label: 'Paid',
              value: ClientBillingScreen._currency.format(paid),
              valueColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          value,
          style: AppTextStyles.price.copyWith(
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  final ClientBill bill;
  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(bill.title, style: AppTextStyles.titleSmall),
              ),
              const SizedBox(width: AppSpacing.s2),
              ClientStatusChip(status: bill.status, label: bill.statusLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ClientBillingScreen._currency.format(bill.amount),
                style: AppTextStyles.price,
              ),
              if (bill.billDate != null)
                Text(
                  df.format(bill.billDate!),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint),
                ),
            ],
          ),
          if (bill.description != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              bill.description!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

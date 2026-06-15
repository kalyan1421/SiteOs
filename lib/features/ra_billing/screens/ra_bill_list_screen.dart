import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/ra_bill.dart';
import '../providers/ra_billing_providers.dart';
import '../widgets/billing_widgets.dart';
import 'ra_bill_detail_screen.dart';
import 'ra_bill_form.dart';

/// Lists all RA bills for the company, newest first.
class RaBillListScreen extends ConsumerWidget {
  const RaBillListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final billsAsync = ref.watch(raBillsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.raBills),
        actions: [
          IconButton(
            tooltip: 'Clients',
            icon: const Icon(Icons.business_outlined),
            onPressed: () => _openClients(context),
          ),
          IconButton(
            tooltip: 'GST settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNew(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newRaBill),
      ),
      body: billsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BillingErrorState(
          error: e,
          onRetry: () => ref.invalidate(raBillsProvider),
        ),
        data: (bills) {
          if (bills.isEmpty) {
            return BillingEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No RA bills yet',
              message:
                  'Create your first Running-Account bill. We auto-calc GST '
                  '(CGST/SGST or IGST), retention, advance recovery and TDS.',
              action: FilledButton.icon(
                onPressed: () => _openNew(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.createRaBill),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(raBillsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: bills.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.s3),
              itemBuilder: (context, i) => _BillTile(bill: bills[i]),
            ),
          );
        },
      ),
    );
  }

  void _openNew(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RaBillForm()),
    );
  }

  void _openClients(BuildContext context) {
    // Prefer go_router if a named route exists; otherwise no-op safe push.
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      try {
        context.goNamed('ra-billing-clients');
        return;
      } catch (_) {
        // route not registered yet — ignore
      }
    }
  }

  void _openSettings(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      try {
        context.goNamed('ra-billing-gst-config');
        return;
      } catch (_) {}
    }
  }
}

class _BillTile extends StatelessWidget {
  final RaBill bill;
  const _BillTile({required this.bill});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final df = DateFormat('dd MMM yyyy');
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RaBillDetailScreen(billId: bill.id),
        ),
      ),
      child: Container(
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
              children: [
                Text(bill.number, style: AppTextStyles.titleMedium),
                const SizedBox(width: AppSpacing.s2),
                StatusBadge(bill.status),
                const Spacer(),
                Text(df.format(bill.billDate),
                    style: AppTextStyles.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            if ((bill.clientName ?? '').isNotEmpty)
              Text(bill.clientName!, style: AppTextStyles.bodyMedium),
            if ((bill.contractName ?? '').isNotEmpty)
              Text(bill.contractName!,
                  style: AppTextStyles.bodySmall),
            const Divider(height: AppSpacing.s5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.taxable, style: AppTextStyles.labelSmall),
                    MoneyText(bill.taxableValue),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.gst, style: AppTextStyles.labelSmall),
                    MoneyText(bill.totalGst,
                        color: AppColors.secondary),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l10n.netPayable, style: AppTextStyles.labelSmall),
                    MoneyText(bill.netPayable,
                        style: AppTextStyles.price,
                        color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/purchase_order.dart';
import '../providers/purchase_providers.dart';
import '../widgets/purchase_widgets.dart';
import 'po_form.dart';
import 'po_grn_match_screen.dart';

/// Lists all purchase orders, lets the user create a new PO, approve a draft,
/// or open the 3-way GRN match for an approved/received PO.
class PoListScreen extends ConsumerWidget {
  const PoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncPos = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.purchaseOrders)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.newPo),
      ),
      body: asyncPos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: AppSpacing.s4),
                Text(e.toString(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.s5),
                FilledButton(
                  onPressed: () => ref.invalidate(purchaseOrdersProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (pos) {
          if (pos.isEmpty) {
            return PurchaseEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No purchase orders',
              message: 'Raise a PO against a supplier to track procurement.',
              actionLabel: 'New PO',
              onAction: () => _openForm(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(purchaseOrdersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: pos.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.s3),
              itemBuilder: (context, i) => _PoCard(
                po: pos[i],
                onApprove: () => _approve(context, ref, pos[i]),
                onMatch: () => _openMatch(context, ref, pos[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PoFormScreen()),
    );
    if (created == true) ref.invalidate(purchaseOrdersProvider);
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    PurchaseOrder po,
  ) async {
    final repo = ref.read(purchaseRepositoryProvider);
    try {
      await repo.updatePoStatus(po.id!, PoStatus.approved);
      ref.invalidate(purchaseOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.poApproved)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _openMatch(
    BuildContext context,
    WidgetRef ref,
    PurchaseOrder po,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PoGrnMatchScreen(poId: po.id!)),
    );
    if (changed == true) ref.invalidate(purchaseOrdersProvider);
  }
}

class _PoCard extends StatelessWidget {
  final PurchaseOrder po;
  final VoidCallback onApprove;
  final VoidCallback onMatch;

  const _PoCard({
    required this.po,
    required this.onApprove,
    required this.onMatch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final itemCount = po.items.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  po.poNo?.isNotEmpty == true ? po.poNo! : 'Purchase Order',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              StatusChip.po(po.status),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 16, color: AppColors.textHint),
              const SizedBox(width: AppSpacing.s1),
              Text('$itemCount line${itemCount == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall),
              const Spacer(),
              Text(l10n.total, style: AppTextStyles.bodySmall),
              const SizedBox(width: AppSpacing.s2),
              Text(
                PurchaseFormat.money(po.total),
                style: AppTextStyles.mono.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (po.status == PoStatus.received && po.mismatchCount > 0) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  '${po.mismatchCount} line(s) flagged in GRN match',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.warningDark),
                ),
              ],
            ),
          ],
          const Divider(height: AppSpacing.s6),
          Align(alignment: Alignment.centerRight, child: _actions(l10n)),
        ],
      ),
    );
  }

  Widget _actions(AppLocalizations l10n) {
    switch (po.status) {
      case PoStatus.draft:
        return FilledButton(
          onPressed: onApprove,
          child: Text(l10n.approve),
        );
      case PoStatus.approved:
        return FilledButton.icon(
          onPressed: onMatch,
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: Text(l10n.receiveMatch),
        );
      case PoStatus.received:
        return TextButton.icon(
          onPressed: onMatch,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: Text(l10n.viewMatch),
        );
      case PoStatus.cancelled:
        return const SizedBox.shrink();
    }
  }
}

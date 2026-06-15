import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../data/models/bill_model.dart';
import '../providers/bill_provider.dart';

class BillsBinScreen extends ConsumerWidget {
  const BillsBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final billsAsync = ref.watch(deletedBillsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Deleted Bills',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: billsAsync.when(
        data: (bills) {
          if (bills.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 30, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.binIsEmpty,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    'Deleted bills appear here.\nYou can restore or permanently delete them.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textHint,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              return _DeletedBillTile(
                bill: bill,
                onRestore: () => _restoreBill(context, ref, bill),
                onPermanentDelete: () =>
                    _permanentlyDelete(context, ref, bill),
              );
            },
          );
        },
        loading: () => const LoadingWidget(message: 'Loading bin...'),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(deletedBillsProvider),
        ),
      ),
    );
  }

  Future<void> _restoreBill(
      BuildContext context, WidgetRef ref, BillModel bill) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Bill?'),
        content: Text('Restore "${bill.title}" back to the active bills?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.restore)),
        ],
      ),
    );
    if (confirmed != true) return;

    final success =
        await ref.read(billControllerProvider.notifier).restoreBill(bill.id);
    if (context.mounted) {
      ref.invalidate(deletedBillsProvider);
      ref.invalidate(dashboardBillsProvider);
      ref.invalidate(dashboardBillsCombinedProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Bill restored' : 'Failed to restore bill'),
        ),
      );
    }
  }

  Future<void> _permanentlyDelete(
      BuildContext context, WidgetRef ref, BillModel bill) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.permanentlyDeleteConfirm),
        content: Text(
            '"${bill.title}" will be removed forever and cannot be recovered.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.deleteForever),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(billRepositoryProvider).permanentlyDeleteBill(bill.id);
      if (context.mounted) {
        ref.invalidate(deletedBillsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.billPermanentlyDeleted)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _DeletedBillTile extends StatelessWidget {
  final BillModel bill;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  const _DeletedBillTile({
    required this.bill,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppColors.error),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${bill.type.label}  ·  ${CurrencyFormatter.formatSimple(bill.amount)}',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (bill.deletedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Deleted ${DateFormat('dd MMM yyyy').format(bill.deletedAt!)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                _ActionBtn(
                  icon: Icons.restore_rounded,
                  color: AppColors.success,
                  tooltip: 'Restore',
                  onTap: onRestore,
                ),
                const SizedBox(height: 6),
                _ActionBtn(
                  icon: Icons.delete_forever_rounded,
                  color: AppColors.error,
                  tooltip: 'Delete forever',
                  onTap: onPermanentDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

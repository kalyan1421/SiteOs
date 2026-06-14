import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/ra_bill.dart';
import '../data/ra_bill_pdf_service.dart';
import '../data/tally_export_service.dart';
import '../providers/ra_billing_providers.dart';
import '../widgets/billing_widgets.dart';

/// Shows a single RA bill with its full breakdown and export actions
/// (PDF tax invoice + Tally XML), plus status transitions.
class RaBillDetailScreen extends ConsumerStatefulWidget {
  final String billId;
  const RaBillDetailScreen({super.key, required this.billId});

  @override
  ConsumerState<RaBillDetailScreen> createState() =>
      _RaBillDetailScreenState();
}

class _RaBillDetailScreenState extends ConsumerState<RaBillDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(raBillProvider(widget.billId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('RA Bill'),
        actions: [
          billAsync.maybeWhen(
            data: (bill) => bill == null
                ? const SizedBox.shrink()
                : PopupMenuButton<String>(
                    onSelected: (v) => _onMenu(v, bill),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'pdf', child: Text('Export PDF')),
                      PopupMenuItem(
                          value: 'print', child: Text('Print preview')),
                      PopupMenuItem(
                          value: 'tally', child: Text('Export Tally XML')),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: billAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BillingErrorState(
          error: e,
          onRetry: () => ref.invalidate(raBillProvider(widget.billId)),
        ),
        data: (bill) {
          if (bill == null) {
            return const BillingEmptyState(
              icon: Icons.search_off,
              title: 'Bill not found',
              message: 'This RA bill may have been deleted.',
            );
          }
          return _body(bill);
        },
      ),
      bottomNavigationBar: billAsync.maybeWhen(
        data: (bill) =>
            bill == null ? null : _actionBar(bill),
        orElse: () => null,
      ),
    );
  }

  Widget _body(RaBill bill) {
    final df = DateFormat('dd MMM yyyy');
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      children: [
        Row(
          children: [
            Text(bill.number, style: AppTextStyles.headlineSmall),
            const SizedBox(width: AppSpacing.s3),
            StatusBadge(bill.status),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(df.format(bill.billDate), style: AppTextStyles.bodySmall),
        if ((bill.clientName ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(bill.clientName!, style: AppTextStyles.titleMedium),
        ],
        if ((bill.contractName ?? '').isNotEmpty)
          Text(bill.contractName!, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.s5),
        _card(
          title: 'Work done',
          children: [
            AmountRow(
                label: 'Cumulative work done',
                amount: bill.cumulativeWorkDone),
            AmountRow(
                label: 'Previous work done',
                amount: bill.previousWorkDone,
                negative: true),
            const Divider(),
            AmountRow(
                label: 'Value of this bill',
                amount: bill.thisBillValue,
                emphasize: false),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        _card(
          title: 'Deductions & GST',
          children: [
            AmountRow(
                label: 'Retention', amount: bill.retention, negative: true),
            AmountRow(
                label: 'Advance recovery',
                amount: bill.advanceRecovery,
                negative: true),
            const Divider(),
            AmountRow(label: 'Taxable value', amount: bill.taxableValue),
            if (bill.cgst > 0) AmountRow(label: 'CGST', amount: bill.cgst),
            if (bill.sgst > 0) AmountRow(label: 'SGST', amount: bill.sgst),
            if (bill.igst > 0) AmountRow(label: 'IGST', amount: bill.igst),
            AmountRow(label: 'TDS', amount: bill.tds, negative: true),
            const Divider(),
            AmountRow(
                label: 'Net payable',
                amount: bill.netPayable,
                emphasize: true),
          ],
        ),
        if ((bill.notes ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s4),
          _card(
            title: 'Notes',
            children: [
              Text(bill.notes!, style: AppTextStyles.bodyMedium),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
      ],
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
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
          Text(title.toUpperCase(), style: AppTextStyles.overline),
          const SizedBox(height: AppSpacing.s2),
          ...children,
        ],
      ),
    );
  }

  Widget _actionBar(RaBill bill) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _exportTally(bill),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Tally XML'),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _exportPdf(bill),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMenu(String value, RaBill bill) {
    switch (value) {
      case 'pdf':
        _exportPdf(bill);
        break;
      case 'print':
        _printPdf(bill);
        break;
      case 'tally':
        _exportTally(bill);
        break;
    }
  }

  Future<void> _exportPdf(RaBill bill) async {
    setState(() => _busy = true);
    try {
      final config = ref.read(gstConfigProvider).valueOrNull;
      await const RaBillPdfService().shareOrPrint(bill: bill, config: config);
    } catch (e) {
      _snack('PDF export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPdf(RaBill bill) async {
    setState(() => _busy = true);
    try {
      final config = ref.read(gstConfigProvider).valueOrNull;
      await const RaBillPdfService().printPreview(bill: bill, config: config);
    } catch (e) {
      _snack('Print failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportTally(RaBill bill) async {
    setState(() => _busy = true);
    try {
      final config = ref.read(gstConfigProvider).valueOrNull;
      await const TallyExportService().exportAndShare(bill: bill, config: config);
    } catch (e) {
      _snack('Tally export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

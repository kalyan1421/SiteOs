import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/purchase_order.dart';
import '../providers/purchase_providers.dart';
import '../widgets/purchase_widgets.dart';

/// 3-way GRN match screen.
///
/// For each PO line it shows the ordered qty (PO), the rate, and lets the user
/// enter the received (GRN) qty. Lines where received != ordered are flagged.
/// Saving persists received quantities; when every line matches, the PO is
/// marked 'received'.
class PoGrnMatchScreen extends ConsumerStatefulWidget {
  final String poId;
  const PoGrnMatchScreen({super.key, required this.poId});

  @override
  ConsumerState<PoGrnMatchScreen> createState() => _PoGrnMatchScreenState();
}

class _PoGrnMatchScreenState extends ConsumerState<PoGrnMatchScreen> {
  /// po_items.id -> received qty controller.
  final Map<String, TextEditingController> _controllers = {};
  bool _initialised = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers(PurchaseOrder po) {
    if (_initialised) return;
    for (final item in po.items) {
      if (item.id == null) continue;
      final initial = item.receivedQty > 0
          ? _fmtQty(item.receivedQty)
          : _fmtQty(item.qty); // default GRN qty to ordered qty
      _controllers[item.id!] = TextEditingController(text: initial);
    }
    _initialised = true;
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncPo = ref.watch(purchaseOrderDetailProvider(widget.poId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.grnMatch)),
      body: asyncPo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s8),
            child: Text(e.toString(), style: AppTextStyles.bodySmall),
          ),
        ),
        data: (po) {
          _initControllers(po);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  children: [
                    _header(po),
                    const SizedBox(height: AppSpacing.s4),
                    Text(l10n.lineItems, style: AppTextStyles.titleSmall),
                    const SizedBox(height: AppSpacing.s2),
                    ...po.items.map(_lineCard),
                  ],
                ),
              ),
              _bottomBar(po),
            ],
          );
        },
      ),
    );
  }

  Widget _header(PurchaseOrder po) {
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
          const SizedBox(height: AppSpacing.s3),
          DetailRow(
            label: AppLocalizations.of(context)!.poTotal,
            value: PurchaseFormat.money(po.total),
            mono: true,
          ),
          DetailRow(
            label: 'Lines',
            value: '${po.items.length}',
          ),
        ],
      ),
    );
  }

  Widget _lineCard(PoItem item) {
    final controller = item.id == null ? null : _controllers[item.id!];
    final received = double.tryParse(controller?.text.trim() ?? '') ?? 0;
    final variance = item.qty - received;
    final matched = variance.abs() < 0.001;
    final flagColor = matched ? AppColors.success : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: matched ? AppColors.border : flagColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.material, style: AppTextStyles.titleSmall),
              ),
              Icon(
                matched
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
                color: flagColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _stat('Ordered', PurchaseFormat.qty(item.qty), item.unit),
              const SizedBox(width: AppSpacing.s4),
              _stat('Rate', PurchaseFormat.money(item.rate), null, mono: true),
              const Spacer(),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    labelText: 'Received',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s2,
              vertical: AppSpacing.s1,
            ),
            decoration: BoxDecoration(
              color: flagColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              matched
                  ? 'Matched — received equals ordered.'
                  : variance > 0
                      ? 'Short by ${PurchaseFormat.qty(variance)} ${item.unit ?? ''}'.trim()
                      : 'Over by ${PurchaseFormat.qty(variance.abs())} ${item.unit ?? ''}'.trim(),
              style: AppTextStyles.labelSmall.copyWith(
                color: matched ? AppColors.successDark : AppColors.warningDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String? unit, {bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: 2),
        Text(
          unit == null ? value : '$value $unit',
          style: (mono ? AppTextStyles.mono : AppTextStyles.bodyMedium)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _bottomBar(PurchaseOrder po) {
    final mismatches = po.items.where((item) {
      final c = item.id == null ? null : _controllers[item.id!];
      final received = double.tryParse(c?.text.trim() ?? '') ?? 0;
      return (item.qty - received).abs() >= 0.001;
    }).length;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    mismatches == 0
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    color:
                        mismatches == 0 ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      mismatches == 0
                          ? 'All lines match'
                          : '$mismatches line(s) flagged',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _saving ? null : () => _save(po),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context)!.saveGrn),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(PurchaseOrder po) async {
    final received = <String, double>{};
    for (final item in po.items) {
      if (item.id == null) continue;
      final c = _controllers[item.id!];
      received[item.id!] = double.tryParse(c?.text.trim() ?? '') ?? 0;
    }

    setState(() => _saving = true);
    final repo = ref.read(purchaseRepositoryProvider);
    try {
      final updated = await repo.recordGrnMatch(po.id!, received);
      ref.invalidate(purchaseOrderDetailProvider(widget.poId));
      ref.invalidate(purchaseOrdersProvider);
      if (mounted) {
        final msg = updated.isFullyMatched
            ? 'GRN saved. PO marked received.'
            : 'GRN saved. ${updated.mismatchCount} line(s) still flagged.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save GRN: $e')),
        );
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/purchase_indent.dart';
import '../data/models/purchase_order.dart';
import '../providers/purchase_providers.dart';
import '../widgets/purchase_widgets.dart';

/// Holds editable state for a single PO line during form entry.
class _PoLine {
  final Key key = UniqueKey();
  final TextEditingController material = TextEditingController();
  final TextEditingController qty = TextEditingController();
  final TextEditingController unit = TextEditingController();
  final TextEditingController rate = TextEditingController();

  double get amount {
    final q = double.tryParse(qty.text.trim()) ?? 0;
    final r = double.tryParse(rate.text.trim()) ?? 0;
    return PoItem.computeAmount(q, r);
  }

  PoItem? toModel() {
    final q = double.tryParse(qty.text.trim()) ?? 0;
    final r = double.tryParse(rate.text.trim()) ?? 0;
    if (material.text.trim().isEmpty || q <= 0) return null;
    return PoItem(
      material: material.text.trim(),
      qty: q,
      unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
      rate: r,
      amount: PoItem.computeAmount(q, r),
    );
  }

  void dispose() {
    material.dispose();
    qty.dispose();
    unit.dispose();
    rate.dispose();
  }
}

/// Form to create a purchase order. Lines can be entered manually or seeded
/// from an approved indent.
class PoFormScreen extends ConsumerStatefulWidget {
  const PoFormScreen({super.key});

  @override
  ConsumerState<PoFormScreen> createState() => _PoFormScreenState();
}

class _PoFormScreenState extends ConsumerState<PoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _poNo = TextEditingController();
  final _notes = TextEditingController();
  String? _supplierId;
  String? _indentId;
  final List<_PoLine> _lines = [_PoLine()];
  bool _saving = false;

  @override
  void dispose() {
    _poNo.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _total => _lines.fold<double>(0, (sum, l) => sum + l.amount);

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(supplierOptionsProvider);
    final approvedIndents = ref.watch(approvedIndentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Purchase Order')),
      bottomNavigationBar: _buildBottomBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            TextFormField(
              controller: _poNo,
              decoration: const InputDecoration(
                labelText: 'PO No. (optional)',
                hintText: 'PO-001',
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            suppliers.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, st) => _supplierManualNote(),
              data: (options) {
                if (options.isEmpty) return _supplierManualNote();
                return DropdownButtonFormField<String>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: options
                      .map((o) => DropdownMenuItem(
                            value: o.id,
                            child: Text(o.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _supplierId = v),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s4),
            approvedIndents.when(
              loading: () => const SizedBox.shrink(),
              error: (err, st) => const SizedBox.shrink(),
              data: (indents) {
                if (indents.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<String>(
                  initialValue: _indentId,
                  decoration: const InputDecoration(
                    labelText: 'Seed from approved indent (optional)',
                  ),
                  items: indents
                      .map((i) => DropdownMenuItem(
                            value: i.id,
                            child: Text(
                              i.title?.isNotEmpty == true
                                  ? i.title!
                                  : (i.indentNo ?? 'Indent'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => _seedFromIndent(indents, v),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              children: [
                Text('Line items', style: AppTextStyles.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _lines.add(_PoLine())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add line'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            ..._lines.map(_buildLine),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: AppSpacing.s10),
          ],
        ),
      ),
    );
  }

  Widget _supplierManualNote() => Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          'No suppliers found. The PO will be created without a supplier link.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.infoDark),
        ),
      );

  Widget _buildLine(_PoLine l) {
    return Container(
      key: l.key,
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: l.material,
            decoration: const InputDecoration(labelText: 'Material'),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: l.qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: TextFormField(
                  controller: l.unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: TextFormField(
                  controller: l.rate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rate ₹'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Text('Amount', style: AppTextStyles.bodySmall),
              const SizedBox(width: AppSpacing.s2),
              Text(
                PurchaseFormat.money(l.amount),
                style: AppTextStyles.mono.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_lines.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    l.dispose();
                    _lines.remove(l);
                  }),
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PO Total', style: AppTextStyles.bodySmall),
                Text(
                  PurchaseFormat.money(_total),
                  style: AppTextStyles.price,
                ),
              ],
            ),
            const Spacer(),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create PO'),
            ),
          ],
        ),
      ),
    );
  }

  void _seedFromIndent(List<PurchaseIndent> indents, String? id) {
    setState(() {
      _indentId = id;
      if (id == null) return;
      final indent = indents.firstWhere((i) => i.id == id);
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      if (indent.items.isEmpty) {
        _lines.add(_PoLine());
      } else {
        for (final item in indent.items) {
          final line = _PoLine();
          line.material.text = item.material;
          line.qty.text = item.qty == item.qty.roundToDouble()
              ? item.qty.toInt().toString()
              : item.qty.toString();
          line.unit.text = item.unit ?? '';
          _lines.add(line);
        }
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final items = _lines.map((l) => l.toModel()).whereType<PoItem>().toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one valid line item.')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(purchaseRepositoryProvider);
    final po = PurchaseOrder(
      poNo: _poNo.text.trim().isEmpty ? null : _poNo.text.trim(),
      supplierId: _supplierId,
      indentId: _indentId,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      status: PoStatus.draft,
      total: _total,
    );

    try {
      await repo.createPurchaseOrder(po, items);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create PO: $e')),
        );
      }
    }
  }
}

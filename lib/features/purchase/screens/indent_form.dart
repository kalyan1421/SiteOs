import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/purchase_indent.dart';
import '../providers/purchase_providers.dart';

/// Holds editable state for a single indent line during form entry.
class _ItemEntry {
  final Key key = UniqueKey();
  final TextEditingController material = TextEditingController();
  final TextEditingController qty = TextEditingController();
  final TextEditingController unit = TextEditingController();

  IndentItem? toModel() {
    final q = double.tryParse(qty.text.trim()) ?? 0;
    if (material.text.trim().isEmpty || q <= 0) return null;
    return IndentItem(
      material: material.text.trim(),
      qty: q,
      unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
    );
  }

  void dispose() {
    material.dispose();
    qty.dispose();
    unit.dispose();
  }
}

/// Form to create a new purchase indent with one or more material lines.
class IndentFormScreen extends ConsumerStatefulWidget {
  const IndentFormScreen({super.key});

  @override
  ConsumerState<IndentFormScreen> createState() => _IndentFormScreenState();
}

class _IndentFormScreenState extends ConsumerState<IndentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _indentNo = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _requiredBy;
  final List<_ItemEntry> _items = [_ItemEntry()];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _indentNo.dispose();
    _notes.dispose();
    for (final e in _items) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.newIndent)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Foundation steel request',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _indentNo,
              decoration: const InputDecoration(
                labelText: 'Indent No. (optional)',
                hintText: 'IND-001',
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Required by',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _requiredBy == null
                      ? 'Select a date'
                      : '${_requiredBy!.day}/${_requiredBy!.month}/${_requiredBy!.year}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _requiredBy == null
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              children: [
                Text(l10n.items, style: AppTextStyles.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemEntry())),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addItem),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            ..._items.map(_buildItemRow),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.createIndent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(_ItemEntry e) {
    return Container(
      key: e.key,
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
            controller: e.material,
            decoration: const InputDecoration(labelText: 'Material'),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: e.qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty'),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: TextFormField(
                  controller: e.unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'bags, kg, m³',
                  ),
                ),
              ),
              if (_items.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    e.dispose();
                    _items.remove(e);
                  }),
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _requiredBy ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _requiredBy = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final items = _items.map((e) => e.toModel()).whereType<IndentItem>().toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fillAllRequiredFields)),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(purchaseRepositoryProvider);
    final indent = PurchaseIndent(
      title: _title.text.trim(),
      indentNo: _indentNo.text.trim().isEmpty ? null : _indentNo.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      requiredBy: _requiredBy,
      status: IndentStatus.draft,
    );

    try {
      await repo.createIndent(indent, items);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create indent: $e')),
        );
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../providers/boq_providers.dart';
import '../widgets/boq_money_text.dart';

/// Bottom-sheet form to add a single line item to a BOQ, grouped by category.
/// Pops with `true` when an item was added.
class BoqItemForm extends ConsumerStatefulWidget {
  final String boqId;

  /// Pre-fill the category (e.g. when adding into an existing accordion group).
  final String? initialCategory;

  /// Known categories already on this BOQ — surfaced as quick-pick chips.
  final List<String> existingCategories;

  const BoqItemForm({
    super.key,
    required this.boqId,
    this.initialCategory,
    this.existingCategories = const [],
  });

  @override
  ConsumerState<BoqItemForm> createState() => _BoqItemFormState();
}

class _BoqItemFormState extends ConsumerState<BoqItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _categoryController;
  final _descriptionController = TextEditingController();
  final _unitController = TextEditingController(text: 'nos');
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryController =
        TextEditingController(text: widget.initialCategory ?? '');
    _qtyController.addListener(_refreshPreview);
    _rateController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _refreshPreview() => setState(() {});

  double get _previewAmount {
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    final rate = double.tryParse(_rateController.text.trim()) ?? 0;
    return qty * rate;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final companyId = ref.read(boqCompanyIdProvider);
    if (companyId == null || companyId.isEmpty) {
      setState(() => _error =
          'Your account is not linked to a company yet. Please re-login.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(boqRepositoryProvider);
      await repo.addItem(
        companyId: companyId,
        boqId: widget.boqId,
        category: _categoryController.text.trim().isEmpty
            ? 'General'
            : _categoryController.text.trim(),
        description: _descriptionController.text.trim(),
        unit: _unitController.text.trim().isEmpty
            ? 'nos'
            : _unitController.text.trim(),
        qty: double.parse(_qtyController.text.trim()),
        rate: double.parse(_rateController.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  String? _numberValidator(String? v, {required String label}) {
    if (v == null || v.trim().isEmpty) return 'Enter $label';
    final n = double.tryParse(v.trim());
    if (n == null) return 'Invalid number';
    if (n < 0) return 'Must be ≥ 0';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s5, AppSpacing.s4, AppSpacing.s5, AppSpacing.s5),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('Add line item', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.s5),

              TextFormField(
                controller: _categoryController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g. Earthwork, Concrete, Steel',
                ),
              ),
              if (widget.existingCategories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s2),
                Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s1,
                  children: widget.existingCategories
                      .map((c) => ActionChip(
                            label: Text(c, style: AppTextStyles.labelSmall),
                            onPressed: () =>
                                _categoryController.text = c,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.s4),

              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. PCC 1:4:8 in foundation',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a description'
                    : null,
              ),
              const SizedBox(height: AppSpacing.s4),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _unitController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'cum / sqm / kg',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        hintText: '0',
                      ),
                      validator: (v) =>
                          _numberValidator(v, label: 'quantity'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),

              TextFormField(
                controller: _rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Rate (₹ per unit)',
                  hintText: '0.00',
                  prefixText: '₹ ',
                ),
                validator: (v) => _numberValidator(v, label: 'rate'),
              ),
              const SizedBox(height: AppSpacing.s4),

              // Live amount preview (mono).
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Line amount', style: AppTextStyles.labelMedium),
                    BoqMoneyText(
                      _previewAmount,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s3),
                Text(_error!, style: AppTextStyles.error),
              ],
              const SizedBox(height: AppSpacing.s5),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

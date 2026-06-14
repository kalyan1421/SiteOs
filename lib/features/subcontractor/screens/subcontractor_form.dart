import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/subcontractor_model.dart';
import '../providers/subcontractor_providers.dart';

/// Create / edit a subcontractor. Pushed as a full screen from the list.
/// Pass [existing] to edit; omit to create.
class SubcontractorForm extends ConsumerStatefulWidget {
  final SubcontractorModel? existing;

  const SubcontractorForm({super.key, this.existing});

  @override
  ConsumerState<SubcontractorForm> createState() => _SubcontractorFormState();
}

class _SubcontractorFormState extends ConsumerState<SubcontractorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _gstin;
  late final TextEditingController _pan;
  late final TextEditingController _specialization;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _gstin = TextEditingController(text: e?.gstin ?? '');
    _pan = TextEditingController(text: e?.pan ?? '');
    _specialization = TextEditingController(text: e?.specialization ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _address = TextEditingController(text: e?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _gstin.dispose();
    _pan.dispose();
    _specialization.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final companyId = ref.read(currentCompanyIdProvider);
    if (companyId == null) {
      _toast('No company found for your account.');
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(subcontractorRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateSubcontractor(
          widget.existing!.copyWith(
            name: _name.text.trim(),
            gstin: _gstin.text.trim(),
            pan: _pan.text.trim(),
            specialization: _specialization.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            address: _address.text.trim(),
          ),
        );
      } else {
        await repo.createSubcontractor(
          companyId: companyId,
          name: _name.text.trim(),
          gstin: _gstin.text.trim(),
          pan: _pan.text.trim(),
          specialization: _specialization.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
        );
      }
      ref.invalidate(subcontractorsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Subcontractor' : 'New Subcontractor'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Firm or individual name',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _specialization,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Specialization',
                  hintText: 'e.g. Plumbing, RCC, Electrical',
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _gstin,
                textCapitalization: TextCapitalization.characters,
                maxLength: 15,
                decoration: const InputDecoration(
                  labelText: 'GSTIN',
                  hintText: '15-character GST number',
                  counterText: '',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  return t.length == 15 ? null : 'GSTIN must be 15 characters';
                },
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _pan,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'PAN',
                  hintText: '10-character PAN',
                  counterText: '',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  return t.length == 10 ? null : 'PAN must be 10 characters';
                },
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _address,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: AppSpacing.s6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                      : Text(_isEdit ? 'Save changes' : 'Create subcontractor',
                          style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

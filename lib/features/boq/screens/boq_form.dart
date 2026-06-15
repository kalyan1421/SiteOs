import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../providers/boq_providers.dart';

/// Bottom-sheet form to create a new BOQ header for a project.
/// Pops with `true` when a BOQ was created.
class BoqForm extends ConsumerStatefulWidget {
  final String projectId;

  const BoqForm({super.key, required this.projectId});

  @override
  ConsumerState<BoqForm> createState() => _BoqFormState();
}

class _BoqFormState extends ConsumerState<BoqForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _versionController = TextEditingController(text: 'v1');
  final _notesController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _versionController.dispose();
    _notesController.dispose();
    super.dispose();
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
      await repo.createHeader(
        companyId: companyId,
        projectId: widget.projectId,
        name: _nameController.text.trim(),
        version: _versionController.text.trim().isEmpty
            ? 'v1'
            : _versionController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
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
              Text(l10n.newBoq, style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'Give this estimate a name and version.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s5),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'BOQ name',
                  hintText: 'e.g. Civil works estimate',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _versionController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Version',
                  hintText: 'v1',
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Scope, assumptions, exclusions…',
                  alignLabelWithHint: true,
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
                      : Text(l10n.createBoq),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

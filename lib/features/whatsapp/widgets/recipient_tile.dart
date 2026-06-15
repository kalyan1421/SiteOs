import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/whatsapp_recipient.dart';

/// A read-only row for a configured WhatsApp recipient, with a delete action.
class RecipientTile extends StatelessWidget {
  final WhatsAppRecipient recipient;
  final VoidCallback onRemove;

  const RecipientTile({
    super.key,
    required this.recipient,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_rounded,
                size: 20, color: AppColors.successDark),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.name.isEmpty ? 'Unnamed' : recipient.name,
                  style: AppTextStyles.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  recipient.phone,
                  style: AppTextStyles.mono.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded,
                size: 20, color: AppColors.textHint),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet form to add a recipient. Returns the new recipient via the
/// [onAdd] callback when valid, else null on cancel.
class AddRecipientSheet extends StatefulWidget {
  final ValueChanged<WhatsAppRecipient> onAdd;

  const AddRecipientSheet({super.key, required this.onAdd});

  static Future<void> show(
    BuildContext context,
    ValueChanged<WhatsAppRecipient> onAdd,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.xlR),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddRecipientSheet(onAdd: onAdd),
      ),
    );
  }

  @override
  State<AddRecipientSheet> createState() => _AddRecipientSheetState();
}

class _AddRecipientSheetState extends State<AddRecipientSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';
    // Accept an optional leading + and 10–15 digits (E.164-ish).
    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10 || digits.length > 15) {
      return 'Enter a valid phone with country code, e.g. +91 98765 43210';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onAdd(WhatsAppRecipient(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add recipient', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.s5),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Site Owner',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number',
                hintText: '+91 98765 43210',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
              validator: _validatePhone,
            ),
            const SizedBox(height: AppSpacing.s6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Add recipient'),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

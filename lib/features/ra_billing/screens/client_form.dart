import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/client.dart';
import '../providers/ra_billing_providers.dart';

/// Bottom-sheet form to create or edit a billing client.
class ClientForm extends ConsumerStatefulWidget {
  /// When non-null, the form edits an existing client.
  final BillingClient? existing;

  const ClientForm({super.key, this.existing});

  /// Opens the form as a modal bottom sheet. Returns true if saved.
  static Future<bool?> show(BuildContext context, {BillingClient? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ClientForm(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<ClientForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _gstin;
  late final TextEditingController _stateCode;
  late final TextEditingController _address;
  late final TextEditingController _contactPerson;
  late final TextEditingController _contactPhone;
  late final TextEditingController _contactEmail;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _gstin = TextEditingController(text: e?.gstin ?? '');
    _stateCode = TextEditingController(text: e?.stateCode ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _contactPerson = TextEditingController(text: e?.contactPerson ?? '');
    _contactPhone = TextEditingController(text: e?.contactPhone ?? '');
    _contactEmail = TextEditingController(text: e?.contactEmail ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _gstin.dispose();
    _stateCode.dispose();
    _address.dispose();
    _contactPerson.dispose();
    _contactPhone.dispose();
    _contactEmail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final companyId = ref.read(billingCompanyIdProvider);
    if (companyId == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(raBillingRepositoryProvider);
      final model = BillingClient(
        id: widget.existing?.id ?? '',
        companyId: companyId,
        name: _name.text.trim(),
        gstin: _opt(_gstin),
        stateCode: _opt(_stateCode),
        address: _opt(_address),
        contactPerson: _opt(_contactPerson),
        contactPhone: _opt(_contactPhone),
        contactEmail: _opt(_contactEmail),
      );
      if (widget.existing == null) {
        await repo.createClient(companyId: companyId, client: model);
      } else {
        await repo.updateClient(id: widget.existing!.id, client: model);
      }
      ref.invalidate(clientsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _opt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s4),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? l10n.newClient : l10n.edit,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s4),
            _field(_name, 'Client name', validator: _required),
            _field(_gstin, 'GSTIN',
                textCapitalization: TextCapitalization.characters),
            _field(_stateCode, 'State code (e.g. 27)'),
            _field(_address, 'Address', maxLines: 2),
            _field(_contactPerson, 'Contact person'),
            _field(_contactPhone, 'Contact phone',
                keyboardType: TextInputType.phone),
            _field(_contactEmail, 'Contact email',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: AppSpacing.s4),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.existing == null ? l10n.add : l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

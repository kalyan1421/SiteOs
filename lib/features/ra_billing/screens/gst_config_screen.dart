import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/gst_config.dart';
import '../providers/ra_billing_providers.dart';
import '../widgets/billing_widgets.dart';

/// Set up the company's GST identity + bank details used on RA bills / Tally.
class GstConfigScreen extends ConsumerStatefulWidget {
  const GstConfigScreen({super.key});

  @override
  ConsumerState<GstConfigScreen> createState() => _GstConfigScreenState();
}

class _GstConfigScreenState extends ConsumerState<GstConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legalName = TextEditingController();
  final _gstin = TextEditingController();
  final _stateCode = TextEditingController();
  final _pan = TextEditingController();
  final _address = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccountNo = TextEditingController();
  final _bankIfsc = TextEditingController();
  final _bankBranch = TextEditingController();
  final _defaultTds = TextEditingController(text: '0');

  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _legalName.dispose();
    _gstin.dispose();
    _stateCode.dispose();
    _pan.dispose();
    _address.dispose();
    _bankName.dispose();
    _bankAccountNo.dispose();
    _bankIfsc.dispose();
    _bankBranch.dispose();
    _defaultTds.dispose();
    super.dispose();
  }

  void _seed(GstConfig? config) {
    if (_seeded || config == null) return;
    _seeded = true;
    _legalName.text = config.legalName ?? '';
    _gstin.text = config.gstin ?? '';
    _stateCode.text = config.stateCode ?? '';
    _pan.text = config.pan ?? '';
    _address.text = config.address ?? '';
    _bankName.text = config.bankName ?? '';
    _bankAccountNo.text = config.bankAccountNo ?? '';
    _bankIfsc.text = config.bankIfsc ?? '';
    _bankBranch.text = config.bankBranch ?? '';
    _defaultTds.text = config.defaultTdsPct.toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final companyId = ref.read(billingCompanyIdProvider);
    if (companyId == null) {
      _snack('No company found for your account.');
      return;
    }
    setState(() => _saving = true);
    try {
      final config = GstConfig(
        id: '',
        companyId: companyId,
        legalName: _trim(_legalName),
        gstin: _trim(_gstin),
        stateCode: _trim(_stateCode),
        pan: _trim(_pan),
        address: _trim(_address),
        bankName: _trim(_bankName),
        bankAccountNo: _trim(_bankAccountNo),
        bankIfsc: _trim(_bankIfsc),
        bankBranch: _trim(_bankBranch),
        defaultTdsPct: double.tryParse(_defaultTds.text.trim()) ?? 0,
      );
      await ref
          .read(raBillingRepositoryProvider)
          .upsertGstConfig(companyId: companyId, config: config);
      ref.invalidate(gstConfigProvider);
      if (mounted) {
        _snack('GST settings saved.');
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _trim(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(gstConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GST Settings')),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BillingErrorState(
          error: e,
          onRetry: () => ref.invalidate(gstConfigProvider),
        ),
        data: (config) {
          _seed(config);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              children: [
                _section('Business identity'),
                _field(_legalName, 'Legal / trade name',
                    validator: _required),
                _field(_gstin, 'GSTIN', textCapitalization: TextCapitalization.characters),
                _field(_stateCode, 'State code (e.g. 27, 29)',
                    keyboardType: TextInputType.text),
                _field(_pan, 'PAN', textCapitalization: TextCapitalization.characters),
                _field(_address, 'Registered address', maxLines: 3),
                const SizedBox(height: AppSpacing.s6),
                _section('Bank details (for invoices)'),
                _field(_bankName, 'Bank name'),
                _field(_bankAccountNo, 'Account number',
                    keyboardType: TextInputType.number),
                _field(_bankIfsc, 'IFSC',
                    textCapitalization: TextCapitalization.characters),
                _field(_bankBranch, 'Branch'),
                const SizedBox(height: AppSpacing.s6),
                _section('Defaults'),
                _field(_defaultTds, 'Default TDS %',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: AppSpacing.s8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save GST settings'),
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s3),
        child: Text(title.toUpperCase(), style: AppTextStyles.overline),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
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

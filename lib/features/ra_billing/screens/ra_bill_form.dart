import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/gst_calculator.dart';
import '../data/models/gst_config.dart';
import '../data/models/project_contract.dart';
import '../data/models/ra_bill.dart';
import '../providers/ra_billing_providers.dart';
import '../widgets/billing_widgets.dart';

/// Create a new RA bill against a contract, with a live GST/retention/TDS
/// breakdown preview that updates as you type.
class RaBillForm extends ConsumerStatefulWidget {
  /// Optionally preselect a contract.
  final String? contractId;

  const RaBillForm({super.key, this.contractId});

  @override
  ConsumerState<RaBillForm> createState() => _RaBillFormState();
}

class _RaBillFormState extends ConsumerState<RaBillForm> {
  final _formKey = GlobalKey<FormState>();
  final _calculator = const GstCalculator();

  ProjectContract? _contract;
  RaBillSeed? _seed;
  DateTime _billDate = DateTime.now();

  final _number = TextEditingController();
  final _cumulative = TextEditingController(text: '0');
  final _previous = TextEditingController(text: '0');
  final _retentionPct = TextEditingController(text: '0');
  final _advanceRecoveryPct = TextEditingController(text: '0');
  final _gstRate = TextEditingController(text: '18');
  final _tdsPct = TextEditingController(text: '0');
  final _notes = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _cumulative,
      _previous,
      _retentionPct,
      _advanceRecoveryPct,
      _gstRate,
      _tdsPct,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _cumulative.dispose();
    _previous.dispose();
    _retentionPct.dispose();
    _advanceRecoveryPct.dispose();
    _gstRate.dispose();
    _tdsPct.dispose();
    _notes.dispose();
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  GstConfig? get _config => ref.read(gstConfigProvider).valueOrNull;

  Future<void> _selectContract(ProjectContract c) async {
    setState(() {
      _contract = c;
      _gstRate.text = c.gstRate.toString();
      _retentionPct.text = c.retentionPct.toString();
      _advanceRecoveryPct.text = c.advanceRecoveryPct.toString();
      _tdsPct.text =
          (c.tdsPct != 0 ? c.tdsPct : (_config?.defaultTdsPct ?? 0)).toString();
    });
    final seed = await ref.read(raBillSeedProvider(c.id).future);
    if (!mounted) return;
    setState(() {
      _seed = seed;
      _previous.text = seed.previousCumulative.toString();
      if (_number.text.trim().isEmpty) _number.text = seed.suggestedNumber;
    });
  }

  GstBreakdown _breakdown() {
    final thisBill = GstCalculator.thisBillValue(
      cumulativeWorkDone: _d(_cumulative),
      previousWorkDone: _d(_previous),
    );
    final advanceOutstanding = _contract == null
        ? double.infinity
        : (_contract!.advance - (_seed?.advanceRecoveredSoFar ?? 0));
    return _calculator.compute(
      thisBillValue: thisBill,
      gstRatePct: _d(_gstRate),
      retentionPct: _d(_retentionPct),
      advanceRecoveryPct: _d(_advanceRecoveryPct),
      advanceOutstanding: advanceOutstanding,
      tdsPct: _d(_tdsPct),
      supplierStateCode: _config?.stateCode,
      clientStateCode: _contract?.clientStateCode,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contract == null) {
      _snack('Select a contract first.');
      return;
    }
    final companyId = ref.read(billingCompanyIdProvider);
    if (companyId == null) return;
    setState(() => _saving = true);
    try {
      final b = _breakdown();
      final bill = RaBill(
        id: '',
        companyId: companyId,
        contractId: _contract!.id,
        number: _number.text.trim(),
        billDate: _billDate,
        cumulativeWorkDone: _d(_cumulative),
        previousWorkDone: _d(_previous),
        thisBillValue: b.thisBillValue,
        advanceRecovery: b.advanceRecovery,
        retention: b.retention,
        taxableValue: b.taxableValue,
        cgst: b.cgst,
        sgst: b.sgst,
        igst: b.igst,
        tds: b.tds,
        netPayable: b.netPayable,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        status: RaBillStatus.pending,
      );
      await ref
          .read(raBillingRepositoryProvider)
          .createBill(companyId: companyId, bill: bill);
      ref.invalidate(raBillsProvider);
      if (mounted) {
        _snack('RA bill created.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      _snack('Could not create bill: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contractsAsync = ref.watch(contractsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newRaBill)),
      body: contractsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BillingErrorState(
          error: e,
          onRetry: () => ref.invalidate(contractsProvider),
        ),
        data: (contracts) {
          if (contracts.isEmpty) {
            return const BillingEmptyState(
              icon: Icons.description_outlined,
              title: 'No contracts yet',
              message:
                  'Create a project contract (client, contract value, retention, '
                  'advance) before raising an RA bill.',
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              children: [
                _label('Contract'),
                DropdownButtonFormField<String>(
                  initialValue: _contract?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Select contract'),
                  items: contracts
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${c.name}${c.clientName != null ? ' · ${c.clientName}' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  validator: (v) => v == null ? 'Required' : null,
                  onChanged: (v) {
                    final c = contracts.firstWhere((e) => e.id == v);
                    _selectContract(c);
                  },
                ),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  children: [
                    Expanded(
                      child: _field(_number, 'Bill number',
                          validator: _required),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(child: _dateField()),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                _label('Work done (cumulative)'),
                Row(
                  children: [
                    Expanded(
                      child: _field(_cumulative, 'Cumulative',
                          number: true, validator: _required),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: _field(_previous, 'Previous', number: true),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                _label('Deductions & tax'),
                Row(
                  children: [
                    Expanded(
                        child: _field(_retentionPct, 'Retention %',
                            number: true)),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                        child: _field(_advanceRecoveryPct, 'Adv. recovery %',
                            number: true)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child:
                            _field(_gstRate, 'GST rate %', number: true)),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(child: _field(_tdsPct, 'TDS %', number: true)),
                  ],
                ),
                _field(_notes, 'Notes (optional)', maxLines: 2),
                const SizedBox(height: AppSpacing.s5),
                _preview(),
                const SizedBox(height: AppSpacing.s6),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.createRaBill),
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _preview() {
    final l10n = AppLocalizations.of(context)!;
    final b = _breakdown();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.livePreview, style: AppTextStyles.overline),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  b.isIntraState ? 'CGST + SGST' : 'IGST',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          AmountRow(label: 'Value of this bill', amount: b.thisBillValue),
          AmountRow(
              label: 'Retention', amount: b.retention, negative: true),
          AmountRow(
              label: 'Advance recovery',
              amount: b.advanceRecovery,
              negative: true),
          const Divider(),
          AmountRow(label: 'Taxable value', amount: b.taxableValue),
          if (b.isIntraState) ...[
            AmountRow(label: 'CGST', amount: b.cgst),
            AmountRow(label: 'SGST', amount: b.sgst),
          ] else
            AmountRow(label: 'IGST', amount: b.igst),
          AmountRow(label: 'TDS', amount: b.tds, negative: true),
          const Divider(),
          AmountRow(
              label: 'Net payable',
              amount: b.netPayable,
              emphasize: true),
        ],
      ),
    );
  }

  Widget _dateField() {
    final df = DateFormat('dd MMM yyyy');
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _billDate,
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _billDate = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Bill date'),
        child: Text(df.format(_billDate), style: AppTextStyles.bodyMedium),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
        child: Text(text.toUpperCase(), style: AppTextStyles.overline),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: number ? AppTextStyles.mono : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

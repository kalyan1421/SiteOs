import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/subcontractor_model.dart';
import '../data/models/work_order_model.dart';
import '../providers/subcontractor_providers.dart';
import '../widgets/money_text.dart';

/// Create / edit a work order for a given subcontractor.
/// Pass [existing] to edit; omit to create.
class WorkOrderForm extends ConsumerStatefulWidget {
  final SubcontractorModel subcontractor;
  final WorkOrderModel? existing;

  const WorkOrderForm({
    super.key,
    required this.subcontractor,
    this.existing,
  });

  @override
  ConsumerState<WorkOrderForm> createState() => _WorkOrderFormState();
}

class _WorkOrderFormState extends ConsumerState<WorkOrderForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _woNumber;
  late final TextEditingController _scope;
  late final TextEditingController _value;
  late final TextEditingController _retentionPct;
  late final TextEditingController _tdsPct;
  late final TextEditingController _notes;

  String? _projectId;
  WorkOrderStatus _status = WorkOrderStatus.active;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  final _dateFmt = DateFormat('dd MMM yyyy');

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _woNumber = TextEditingController(text: e?.woNumber ?? '');
    _scope = TextEditingController(text: e?.scope ?? '');
    _value =
        TextEditingController(text: e != null ? _trim(e.value) : '');
    _retentionPct =
        TextEditingController(text: e != null ? _trim(e.retentionPct) : '');
    _tdsPct = TextEditingController(text: e != null ? _trim(e.tdsPct) : '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _projectId = e?.projectId;
    _status = e?.status ?? WorkOrderStatus.active;
    _startDate = e?.startDate;
    _endDate = e?.endDate;
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _woNumber.dispose();
    _scope.dispose();
    _value.dispose();
    _retentionPct.dispose();
    _tdsPct.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _valueNum => double.tryParse(_value.text.trim()) ?? 0;
  double get _retentionNum => double.tryParse(_retentionPct.text.trim()) ?? 0;

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
        await repo.updateWorkOrder(
          widget.existing!.copyWith(
            projectId: _projectId,
            woNumber: _woNumber.text.trim(),
            scope: _scope.text.trim(),
            value: _valueNum,
            retentionPct: _retentionNum,
            tdsPct: double.tryParse(_tdsPct.text.trim()) ?? 0,
            status: _status,
            startDate: _startDate,
            endDate: _endDate,
            notes: _notes.text.trim(),
          ),
        );
      } else {
        await repo.createWorkOrder(
          companyId: companyId,
          subcontractorId: widget.subcontractor.id,
          projectId: _projectId,
          woNumber: _woNumber.text.trim(),
          scope: _scope.text.trim(),
          value: _valueNum,
          retentionPct: _retentionNum,
          tdsPct: double.tryParse(_tdsPct.text.trim()) ?? 0,
          status: _status,
          startDate: _startDate,
          endDate: _endDate,
          notes: _notes.text.trim(),
        );
      }
      ref.invalidate(workOrdersProvider(widget.subcontractor.id));
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

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectOptionsProvider);
    final retentionAmount = _valueNum * (_retentionNum / 100);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Work Order' : 'New Work Order'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            children: [
              Text(
                widget.subcontractor.name,
                style: AppTextStyles.titleSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _woNumber,
                decoration: const InputDecoration(
                  labelText: 'WO Number',
                  hintText: 'e.g. WO-2026-014',
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              projectsAsync.when(
                data: (projects) => DropdownButtonFormField<String?>(
                  initialValue: _projectId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No project'),
                    ),
                    ...projects.map(
                      (p) => DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _projectId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _scope,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Scope of work *',
                  hintText: 'What this subcontractor will deliver',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Scope is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _value,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Order value (₹) *',
                  prefixText: '₹ ',
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _retentionPct,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Retention %',
                        suffixText: '%',
                      ),
                      validator: _pctValidator,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: TextFormField(
                      controller: _tdsPct,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Default TDS %',
                        suffixText: '%',
                      ),
                      validator: _pctValidator,
                    ),
                  ),
                ],
              ),
              if (_valueNum > 0 && _retentionNum > 0) ...[
                const SizedBox(height: AppSpacing.s3),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: MoneyRow(
                    label: 'Retention held on full value',
                    value: retentionAmount,
                    amountColor: AppColors.warningDark,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              DropdownButtonFormField<WorkOrderStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: WorkOrderStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _status = v ?? WorkOrderStatus.active),
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start date',
                      value: _startDate,
                      formatted:
                          _startDate != null ? _dateFmt.format(_startDate!) : null,
                      onTap: () => _pickDate(start: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: _DateField(
                      label: 'End date',
                      value: _endDate,
                      formatted:
                          _endDate != null ? _dateFmt.format(_endDate!) : null,
                      onTap: () => _pickDate(start: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Notes'),
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
                      : Text(_isEdit ? 'Save changes' : 'Create work order',
                          style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _pctValidator(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || n < 0 || n > 100) return '0–100';
    return null;
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String? formatted;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.formatted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          formatted ?? 'Select',
          style: AppTextStyles.bodyMedium.copyWith(
            color: value == null
                ? AppColors.textHint
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

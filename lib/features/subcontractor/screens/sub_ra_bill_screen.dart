import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/sub_ra_bill_model.dart';
import '../data/models/work_order_model.dart';
import '../providers/subcontractor_providers.dart';
import '../widgets/money_text.dart';
import '../widgets/status_chip.dart';

/// Running-account bills raised against a single work order.
///
/// Each bill records a certified value and deducts TDS + retention; the net is
/// what's actually payable to the subcontractor. The math mirrors the GST/RA
/// billing style used elsewhere in SiteOS:
///   tds       = value × tdsPct / 100
///   retention = value × retentionPct / 100
///   net       = value − tds − retention
class SubRaBillScreen extends ConsumerWidget {
  final WorkOrderModel workOrder;

  const SubRaBillScreen({super.key, required this.workOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBills = ref.watch(raBillsProvider(workOrder.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          workOrder.woNumber?.isNotEmpty == true
              ? workOrder.woNumber!
              : 'RA Bills',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.s4,
              bottom: AppSpacing.s2,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Subcontractor RA Bills',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textOnPrimary),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New RA Bill'),
      ),
      body: asyncBills.when(
        data: (bills) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(raBillsProvider(workOrder.id)),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _WorkOrderSummary(workOrder: workOrder, bills: bills),
              ),
              if (bills.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Empty(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    0,
                    AppSpacing.s4,
                    AppSpacing.s16,
                  ),
                  sliver: SliverList.separated(
                    itemCount: bills.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.s3),
                    itemBuilder: (_, i) => _RaBillCard(
                      bill: bills[i],
                      onStatusChange: (status) =>
                          _changeStatus(context, ref, bills[i], status),
                    ),
                  ),
                ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Error(
          message: '$e',
          onRetry: () => ref.invalidate(raBillsProvider(workOrder.id)),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.xlR),
      ),
      builder: (_) => _RaBillForm(workOrder: workOrder),
    );
    if (created == true) {
      ref.invalidate(raBillsProvider(workOrder.id));
    }
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    SubRaBillModel bill,
    SubRaBillStatus status,
  ) async {
    final repo = ref.read(subcontractorRepositoryProvider);
    try {
      await repo.updateRaBillStatus(bill.id, status);
      ref.invalidate(raBillsProvider(workOrder.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update status: $e')),
        );
      }
    }
  }
}

/// Header card: WO value + cumulative billed / retained / net so far.
class _WorkOrderSummary extends StatelessWidget {
  final WorkOrderModel workOrder;
  final List<SubRaBillModel> bills;

  const _WorkOrderSummary({required this.workOrder, required this.bills});

  @override
  Widget build(BuildContext context) {
    final billed = bills.fold<double>(0, (s, b) => s + b.value);
    final retained = bills.fold<double>(0, (s, b) => s + b.retention);
    final net = bills.fold<double>(0, (s, b) => s + b.net);

    return Container(
      margin: const EdgeInsets.all(AppSpacing.s4),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workOrder.scope,
            style: AppTextStyles.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: AppSpacing.s6),
          MoneyRow(label: 'Order value', value: workOrder.value),
          const SizedBox(height: AppSpacing.s2),
          MoneyRow(label: 'Billed so far', value: billed),
          const SizedBox(height: AppSpacing.s2),
          MoneyRow(
            label: 'Retention held',
            value: retained,
            amountColor: AppColors.warningDark,
          ),
          const SizedBox(height: AppSpacing.s2),
          MoneyRow(
            label: 'Net paid / payable',
            value: net,
            emphasize: true,
            amountColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _RaBillCard extends StatelessWidget {
  final SubRaBillModel bill;
  final ValueChanged<SubRaBillStatus> onStatusChange;

  const _RaBillCard({required this.bill, required this.onStatusChange});

  static final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bill.number.isNotEmpty ? bill.number : 'RA Bill',
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusChip.raBill(bill.status),
              PopupMenuButton<SubRaBillStatus>(
                icon: const Icon(Icons.more_vert, color: AppColors.textHint),
                tooltip: 'Change status',
                onSelected: onStatusChange,
                itemBuilder: (_) => SubRaBillStatus.values
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Text('Mark ${s.label.toLowerCase()}'),
                        ))
                    .toList(),
              ),
            ],
          ),
          if (bill.billDate != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              _dateFmt.format(bill.billDate!),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            ),
          ],
          const Divider(height: AppSpacing.s5),
          MoneyRow(label: 'Bill value', value: bill.value),
          const SizedBox(height: AppSpacing.s2),
          MoneyRow(
            label: 'TDS (${_pct(bill.tdsPct)})',
            value: bill.tds,
            amountColor: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.s2),
          MoneyRow(
            label: 'Retention (${_pct(bill.retentionPct)})',
            value: bill.retention,
            amountColor: AppColors.warningDark,
          ),
          const Divider(height: AppSpacing.s5),
          MoneyRow(
            label: 'Net payable',
            value: bill.net,
            emphasize: true,
            amountColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  static String _pct(double v) =>
      v == v.roundToDouble() ? '${v.toStringAsFixed(0)}%' : '$v%';
}

/// Bottom-sheet form to raise a new RA bill. Live TDS + retention + net preview.
class _RaBillForm extends ConsumerStatefulWidget {
  final WorkOrderModel workOrder;

  const _RaBillForm({required this.workOrder});

  @override
  ConsumerState<_RaBillForm> createState() => _RaBillFormState();
}

class _RaBillFormState extends ConsumerState<_RaBillForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _value;
  late final TextEditingController _tdsPct;
  late final TextEditingController _retentionPct;
  final _notes = TextEditingController();

  DateTime _billDate = DateTime.now();
  bool _saving = false;

  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _number = TextEditingController();
    _value = TextEditingController();
    // Default the bill's TDS / retention from the work order's defaults.
    _tdsPct = TextEditingController(text: _trim(widget.workOrder.tdsPct));
    _retentionPct =
        TextEditingController(text: _trim(widget.workOrder.retentionPct));
  }

  static String _trim(double v) =>
      v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void dispose() {
    _number.dispose();
    _value.dispose();
    _tdsPct.dispose();
    _retentionPct.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _valueNum => double.tryParse(_value.text.trim()) ?? 0;
  double get _tdsNum => double.tryParse(_tdsPct.text.trim()) ?? 0;
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
      await repo.createRaBill(
        companyId: companyId,
        workOrderId: widget.workOrder.id,
        number: _number.text.trim(),
        value: _valueNum,
        tdsPct: _tdsNum,
        retentionPct: _retentionNum,
        billDate: _billDate,
        notes: _notes.text.trim(),
      );
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final calc = SubRaBillModel.calc(
      value: _valueNum,
      tdsPct: _tdsNum,
      retentionPct: _retentionNum,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Text('New RA Bill', style: AppTextStyles.headlineSmall),
                const SizedBox(height: AppSpacing.s5),
                TextFormField(
                  controller: _number,
                  decoration: const InputDecoration(
                    labelText: 'Bill number *',
                    hintText: 'e.g. RA-03',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Bill number is required'
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
                    labelText: 'Bill value (₹) *',
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
                        controller: _tdsPct,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'TDS %',
                          suffixText: '%',
                        ),
                        validator: _pctValidator,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s4),
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
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Bill date',
                      suffixIcon:
                          Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(
                      _dateFmt.format(_billDate),
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: AppSpacing.s5),
                // Live deduction breakdown.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      MoneyRow(label: 'Bill value', value: _valueNum),
                      const SizedBox(height: AppSpacing.s2),
                      MoneyRow(
                        label: 'Less: TDS (${_pctLabel(_tdsNum)})',
                        value: calc.tds,
                        amountColor: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      MoneyRow(
                        label: 'Less: Retention (${_pctLabel(_retentionNum)})',
                        value: calc.retention,
                        amountColor: AppColors.warningDark,
                      ),
                      const Divider(height: AppSpacing.s5),
                      MoneyRow(
                        label: 'Net payable',
                        value: calc.net,
                        emphasize: true,
                        amountColor: AppColors.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
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
                        : Text('Save RA bill', style: AppTextStyles.button),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _pctLabel(double v) =>
      v == v.roundToDouble() ? '${v.toStringAsFixed(0)}%' : '$v%';

  String? _pctValidator(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || n < 0 || n > 100) return '0–100';
    return null;
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.s4),
            Text('No RA bills yet',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Raise a running-account bill to record certified work and '
              'deductions.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: AppSpacing.s4),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

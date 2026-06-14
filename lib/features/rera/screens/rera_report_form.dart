import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/rera_report.dart';
import '../providers/rera_providers.dart';
import '../widgets/rera_widgets.dart';

/// Create or edit a RERA quarterly report.
///
/// When [reportId] is null the form creates a new report; otherwise it loads
/// the existing report and edits it. The project is fixed once chosen on
/// create (it identifies the filing along with quarter/year).
class ReraReportForm extends ConsumerStatefulWidget {
  final String? reportId;
  const ReraReportForm({super.key, this.reportId});

  bool get isEditing => reportId != null;

  @override
  ConsumerState<ReraReportForm> createState() => _ReraReportFormState();
}

class _ReraReportFormState extends ConsumerState<ReraReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _completionCtrl = TextEditingController();
  final _workCtrl = TextEditingController();
  final _receivedCtrl = TextEditingController();
  final _utilizedCtrl = TextEditingController();

  String? _projectId;
  int _quarter = _currentQuarter();
  int _year = DateTime.now().year;
  ReraReportStatus _status = ReraReportStatus.draft;

  bool _saving = false;
  bool _prefilled = false;

  static int _currentQuarter() => ((DateTime.now().month - 1) ~/ 3) + 1;

  @override
  void dispose() {
    _completionCtrl.dispose();
    _workCtrl.dispose();
    _receivedCtrl.dispose();
    _utilizedCtrl.dispose();
    super.dispose();
  }

  void _prefill(ReraReport r) {
    if (_prefilled) return;
    _prefilled = true;
    _projectId = r.projectId;
    _quarter = r.quarter;
    _year = r.year;
    _status = r.status;
    _completionCtrl.text = r.completionPct == 0
        ? ''
        : r.completionPct.toStringAsFixed(
            r.completionPct.truncateToDouble() == r.completionPct ? 0 : 2);
    _workCtrl.text = r.workDescription ?? '';
    _receivedCtrl.text =
        r.fundsReceived == 0 ? '' : r.fundsReceived.toStringAsFixed(0);
    _utilizedCtrl.text =
        r.fundsUtilized == 0 ? '' : r.fundsUtilized.toStringAsFixed(0);
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectId == null) {
      _toast('Please select a project.');
      return;
    }

    final received = _parse(_receivedCtrl);
    final utilized = _parse(_utilizedCtrl);
    final completion = _parse(_completionCtrl);

    setState(() => _saving = true);
    final repo = ref.read(reraRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repo.updateReport(
          id: widget.reportId!,
          quarter: _quarter,
          year: _year,
          completionPct: completion,
          workDescription: _workCtrl.text.trim().isEmpty
              ? null
              : _workCtrl.text.trim(),
          fundsReceived: received,
          fundsUtilized: utilized,
          status: _status,
        );
      } else {
        final companyId = ref.read(reraCompanyIdProvider);
        if (companyId == null) {
          _toast('No company found on your profile. Cannot create report.');
          setState(() => _saving = false);
          return;
        }
        await repo.createReport(
          companyId: companyId,
          projectId: _projectId!,
          quarter: _quarter,
          year: _year,
          completionPct: completion,
          workDescription: _workCtrl.text.trim().isEmpty
              ? null
              : _workCtrl.text.trim(),
          fundsReceived: received,
          fundsUtilized: utilized,
          status: _status,
        );
      }
      ref.invalidate(reraReportsProvider);
      if (widget.reportId != null) {
        ref.invalidate(reraReportProvider(widget.reportId!));
      }
      if (mounted) {
        _toast(widget.isEditing ? 'Report updated.' : 'Report created.');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('Save failed: $e');
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final existing = ref.watch(reraReportProvider(widget.reportId!));
      return existing.when(
        loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Edit RERA report')),
          body: ReraPlaceholder(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load report",
            message: e.toString(),
          ),
        ),
        data: (report) {
          if (report == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit RERA report')),
              body: const ReraPlaceholder(
                icon: Icons.search_off_rounded,
                title: 'Report not found',
                message: 'This report may have been deleted.',
              ),
            );
          }
          _prefill(report);
          return _buildForm(context, lockedProjectName: report.projectName);
        },
      );
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context, {String? lockedProjectName}) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit RERA report' : 'New RERA report'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            _label('Project'),
            if (widget.isEditing)
              _LockedProjectField(name: lockedProjectName)
            else
              _ProjectDropdown(
                value: _projectId,
                onChanged: (v) => setState(() => _projectId = v),
              ),
            const SizedBox(height: AppSpacing.s5),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Quarter'),
                      DropdownButtonFormField<int>(
                        initialValue: _quarter,
                        items: const [1, 2, 3, 4]
                            .map((q) => DropdownMenuItem(
                                  value: q,
                                  child: Text('Q$q'),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _quarter = v ?? _quarter),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Year'),
                      DropdownButtonFormField<int>(
                        initialValue: _year,
                        items: _yearOptions()
                            .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Text('$y'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _year = v ?? _year),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s5),
            _label('Completion %'),
            TextFormField(
              controller: _completionCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                hintText: '0 – 100',
                suffixText: '%',
              ),
              validator: (v) {
                final d = double.tryParse((v ?? '').trim());
                if (v == null || v.trim().isEmpty) {
                  return 'Enter completion %';
                }
                if (d == null) return 'Enter a valid number';
                if (d < 0 || d > 100) return 'Must be between 0 and 100';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s5),
            _label('Work description'),
            TextFormField(
              controller: _workCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Summarise the construction work done this quarter…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            _label('Funds received (₹)'),
            TextFormField(
              controller: _receivedCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: AppTextStyles.mono,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: '0',
              ),
              validator: _amountValidator,
            ),
            const SizedBox(height: AppSpacing.s5),
            _label('Funds utilized (₹)'),
            TextFormField(
              controller: _utilizedCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: AppTextStyles.mono,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: '0',
              ),
              validator: _amountValidator,
            ),
            const SizedBox(height: AppSpacing.s5),
            _label('Filing status'),
            SegmentedButton<ReraReportStatus>(
              segments: const [
                ButtonSegment(
                    value: ReraReportStatus.draft, label: Text('Draft')),
                ButtonSegment(
                    value: ReraReportStatus.submitted,
                    label: Text('Submitted')),
                ButtonSegment(
                    value: ReraReportStatus.approved,
                    label: Text('Approved')),
              ],
              selected: {_status},
              onSelectionChanged: (s) =>
                  setState(() => _status = s.first),
            ),
            const SizedBox(height: AppSpacing.s8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.isEditing
                        ? 'Save changes'
                        : 'Create report'),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
        ),
      ),
    );
  }

  String? _amountValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional, defaults to 0
    final d = double.tryParse(v.trim().replaceAll(',', ''));
    if (d == null) return 'Enter a valid amount';
    if (d < 0) return 'Cannot be negative';
    return null;
  }

  List<int> _yearOptions() {
    final now = DateTime.now().year;
    return [for (var y = now + 1; y >= now - 6; y--) y];
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
        child: Text(text, style: AppTextStyles.labelLarge),
      );
}

class _ProjectDropdown extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _ProjectDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(reraProjectOptionsProvider);
    return options.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        'Failed to load projects: $e',
        style: AppTextStyles.error,
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return Text(
            'No projects available. Create a project first.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Select project'),
          items: projects
              .map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? 'Select a project' : null,
        );
      },
    );
  }
}

class _LockedProjectField extends StatelessWidget {
  final String? name;
  const _LockedProjectField({this.name});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: AppColors.textHint),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              name ?? 'Project',
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

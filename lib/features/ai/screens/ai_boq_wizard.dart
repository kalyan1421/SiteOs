import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/boq_result.dart';
import '../providers/ai_providers.dart';
import '../widgets/ai_widgets.dart';

/// AKS-78 — 3-step wizard collecting project params, then an AI BOQ preview.
class AiBoqWizard extends ConsumerStatefulWidget {
  const AiBoqWizard({super.key});

  @override
  ConsumerState<AiBoqWizard> createState() => _AiBoqWizardState();
}

class _AiBoqWizardState extends ConsumerState<AiBoqWizard> {
  int _step = 0;

  // Step 1 — type
  String _projectType = 'residential';
  // Step 2 — size
  final _areaController = TextEditingController();
  int _floors = 1;
  // Step 3 — quality / location / notes
  String _quality = 'standard';
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  bool _generating = false;
  String? _error;
  BoqResult? _result;

  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static const _projectTypes = [
    ('residential', 'Residential'),
    ('commercial', 'Commercial'),
    ('industrial', 'Industrial'),
    ('villa', 'Villa / Bungalow'),
    ('apartment', 'Apartment block'),
  ];

  static const _qualities = [
    ('basic', 'Basic'),
    ('standard', 'Standard'),
    ('premium', 'Premium'),
  ];

  @override
  void dispose() {
    _areaController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    if (_step == 1) {
      final area = double.tryParse(_areaController.text.trim());
      return area != null && area > 0;
    }
    return true;
  }

  Future<void> _generate() async {
    final area = double.tryParse(_areaController.text.trim());
    if (area == null || area <= 0) {
      setState(() => _error = 'Enter a valid built-up area.');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result = await ref.read(aiRepositoryProvider).generateBoq(
            projectType: _projectType,
            areaSqft: area,
            floors: _floors,
            quality: _quality,
            location: _locationController.text.trim(),
            notes: _notesController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _generating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _BoqPreviewScreen(
        result: _result!,
        currency: _currency,
        onRestart: () => setState(() {
          _result = null;
          _step = 0;
        }),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI BOQ Estimator')),
      body: Stack(
        children: [
          Column(
            children: [
              _StepIndicator(step: _step, total: 3),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: _buildStep(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
                  child: Text(_error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: Row(
                    children: [
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _generating
                                ? null
                                : () => setState(() => _step--),
                            child: const Text('Back'),
                          ),
                        ),
                      if (_step > 0) const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: FilledButton(
                          onPressed: (!_canProceed || _generating)
                              ? null
                              : () {
                                  if (_step < 2) {
                                    setState(() {
                                      _step++;
                                      _error = null;
                                    });
                                  } else {
                                    _generate();
                                  }
                                },
                          child: Text(_step < 2 ? 'Next' : 'Generate BOQ'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_generating)
            const Positioned.fill(
              child: AiBusyOverlay(label: 'Estimating quantities…'),
            ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepCard(
          title: 'What are you building?',
          subtitle: 'Choose the project type.',
          child: Column(
            children: _projectTypes
                .map((t) => RadioListTile<String>(
                      value: t.$1,
                      groupValue: _projectType,
                      title: Text(t.$2),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) =>
                          setState(() => _projectType = v ?? _projectType),
                    ))
                .toList(),
          ),
        );
      case 1:
        return _StepCard(
          title: 'Size of the project',
          subtitle: 'Total built-up area and number of floors.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _areaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Built-up area',
                  suffixText: 'sq.ft',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('Floors', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.s2),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _floors > 1
                        ? () => setState(() => _floors--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Text('$_floors',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontFamily: AppTextStyles.monoFontFamily,
                      )),
                  const SizedBox(width: AppSpacing.s4),
                  IconButton.outlined(
                    onPressed: () => setState(() => _floors++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        );
      case 2:
      default:
        return _StepCard(
          title: 'Finishing & details',
          subtitle: 'Quality tier and any specifics.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quality', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.s2),
              SegmentedButton<String>(
                segments: _qualities
                    .map((q) =>
                        ButtonSegment(value: q.$1, label: Text(q.$2)))
                    .toList(),
                selected: {_quality},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setState(() => _quality = s.first),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (city/region)',
                  hintText: 'e.g. Hyderabad',
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Special requirements, materials, etc.',
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  final int total;
  const _StepIndicator({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      child: Row(
        children: List.generate(total, (i) {
          final active = i <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : AppSpacing.s2),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.s1),
        Text(subtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.s6),
        child,
      ],
    );
  }
}

class _BoqPreviewScreen extends StatelessWidget {
  final BoqResult result;
  final NumberFormat currency;
  final VoidCallback onRestart;

  const _BoqPreviewScreen({
    required this.result,
    required this.currency,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    // Group rows by category for a readable preview.
    final byCategory = <String, List<BoqRow>>{};
    for (final r in result.rows) {
      byCategory.putIfAbsent(r.category, () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BOQ Preview'),
        actions: [
          IconButton(
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _asText()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('BOQ copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          const AiDisclaimerBanner(
            text: 'Indicative AI estimate. Verify quantities and rates before '
                'quoting a client.',
          ),
          const SizedBox(height: AppSpacing.s4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Estimated total', style: AppTextStyles.titleMedium),
                Text(
                  currency.format(result.grandTotal),
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontFamily: AppTextStyles.monoFontFamily,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          ...byCategory.entries.map((e) => _CategoryBlock(
                category: e.key,
                rows: e.value,
                currency: currency,
              )),
          if (result.assumptions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s6),
            Text('ASSUMPTIONS', style: AppTextStyles.labelSmall),
            const SizedBox(height: AppSpacing.s2),
            ...result.assumptions.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(
                          child: Text(a, style: AppTextStyles.bodySmall)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: AppSpacing.s8),
          OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Start over'),
          ),
        ],
      ),
    );
  }

  String _asText() {
    final b = StringBuffer('BILL OF QUANTITIES (indicative)\n\n');
    for (final r in result.rows) {
      b.writeln(
          '${r.category} — ${r.description}: ${r.quantity} ${r.unit} @ '
          '${currency.format(r.rate)} = ${currency.format(r.amount)}');
    }
    b.writeln('\nTOTAL: ${currency.format(result.grandTotal)}');
    return b.toString();
  }
}

class _CategoryBlock extends StatelessWidget {
  final String category;
  final List<BoqRow> rows;
  final NumberFormat currency;

  const _CategoryBlock({
    required this.category,
    required this.rows,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = rows.fold<double>(0, (s, r) => s + r.amount);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s4),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: AppTextStyles.titleSmall),
              Text(currency.format(subtotal),
                  style: AppTextStyles.labelMedium.copyWith(
                    fontFamily: AppTextStyles.monoFontFamily,
                    color: AppColors.textSecondary,
                  )),
            ],
          ),
          const Divider(height: AppSpacing.s4),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.description,
                              style: AppTextStyles.bodyMedium),
                          Text(
                            '${_fmtNum(r.quantity)} ${r.unit} × '
                            '${currency.format(r.rate)}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Text(currency.format(r.amount),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontFamily: AppTextStyles.monoFontFamily,
                        )),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _fmtNum(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

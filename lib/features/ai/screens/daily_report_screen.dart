import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/daily_report_result.dart';
import '../providers/ai_providers.dart';
import '../widgets/ai_widgets.dart';

/// AKS-76 — Generate a WhatsApp-ready daily site report, preview, and share.
class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  String? _projectId;
  DateTime _date = DateTime.now();
  String _language = 'en';
  bool _generating = false;
  String? _error;
  DailyReportResult? _result;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _generate() async {
    if (_projectId == null) {
      setState(() => _error = 'Select a project first.');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result = await ref.read(aiRepositoryProvider).generateDailyReport(
            projectId: _projectId!,
            date: DateFormat('yyyy-MM-dd').format(_date),
            language: _language,
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
    final projects = ref.watch(aiProjectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Report')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            children: [
              const AiDisclaimerBanner(
                text: 'AI drafts a daily summary from attendance & materials. '
                    'Review before forwarding.',
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('Project', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.s2),
              projects.when(
                data: (list) => DropdownButtonFormField<String>(
                  initialValue: _projectId,
                  isExpanded: true,
                  hint: const Text('Select a project'),
                  items: list
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _projectId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text('Could not load projects',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('Date', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.s2),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('Language', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.s2),
              AiLanguageToggle(
                value: _language,
                onChanged: (v) => setState(() => _language = v),
              ),
              const SizedBox(height: AppSpacing.s6),
              FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generate report'),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s6),
                AiErrorState(message: _error!, onRetry: _generate),
              ],
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.s6),
                _ReportPreview(result: _result!),
              ],
            ],
          ),
          if (_generating)
            const Positioned.fill(
              child: AiBusyOverlay(label: 'Drafting report…'),
            ),
        ],
      ),
    );
  }
}

class _ReportPreview extends StatelessWidget {
  final DailyReportResult result;
  const _ReportPreview({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_rounded,
                  color: AppColors.successDark, size: 20),
              const SizedBox(width: AppSpacing.s2),
              Text('WhatsApp preview', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          SelectableText(result.summary, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.summary));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _share(context, result.summary),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows the text in a share sheet. Falls back to clipboard + a bottom sheet
  /// (no share_plus dependency required).
  void _share(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share report', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'The report is copied to your clipboard. Paste it into WhatsApp '
              'or any chat to send.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

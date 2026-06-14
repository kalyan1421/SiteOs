import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/daily_report_result.dart';
import '../providers/ai_providers.dart';
import '../widgets/ai_widgets.dart';

/// AKS-77 — Voice report. The site engineer speaks their daily notes; the
/// device transcribes the speech on-device (speech_to_text), then the
/// transcript is sent to the `ai-daily-report` Edge Function, which turns the
/// raw notes into a clean, WhatsApp-ready summary in English or Hindi.
///
/// All AI inference still runs server-side (Gemini via the Edge Function); only
/// the speech-to-text capture is local. The mic permission is requested by the
/// speech_to_text plugin on first use.
class VoiceReportScreen extends ConsumerStatefulWidget {
  const VoiceReportScreen({super.key});

  @override
  ConsumerState<VoiceReportScreen> createState() => _VoiceReportScreenState();
}

class _VoiceReportScreenState extends ConsumerState<VoiceReportScreen> {
  final SpeechToText _speech = SpeechToText();

  bool _speechReady = false;
  bool _listening = false;
  String _transcript = '';
  double _soundLevel = 0;

  String? _projectId;
  String _language = 'en';

  bool _generating = false;
  String? _error;
  DailyReportResult? _result;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _error = 'Speech recognition error: ${e.errorMsg}';
          });
        },
      );
      if (!mounted) return;
      setState(() => _speechReady = available);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _error = 'Microphone unavailable on this device.';
      });
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    // 'done' / 'notListening' both signal the engine stopped.
    final stopped = status == 'done' || status == 'notListening';
    if (stopped && _listening) {
      setState(() => _listening = false);
    }
  }

  /// The BCP-47 locale the recognizer should use for the chosen UI language.
  String get _localeId => _language == 'hi' ? 'hi_IN' : 'en_IN';

  Future<void> _toggleListening() async {
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) return;
    }

    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    setState(() {
      _error = null;
      _listening = true;
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
      },
      localeId: _localeId,
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 6),
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _clearTranscript() {
    setState(() {
      _transcript = '';
      _result = null;
      _error = null;
    });
  }

  Future<void> _generate() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
    }
    if (_projectId == null) {
      setState(() => _error = 'Select a project first.');
      return;
    }
    if (_transcript.trim().isEmpty) {
      setState(() => _error = 'Record your notes before generating.');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result = await ref.read(aiRepositoryProvider).generateDailyReport(
            projectId: _projectId!,
            date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            language: _language,
            transcript: _transcript.trim(),
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
      appBar: AppBar(title: const Text('Voice Report')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            children: [
              const AiDisclaimerBanner(
                text: 'Speak your daily notes — AI turns them into a clean '
                    'WhatsApp summary. Review before sharing.',
                icon: Icons.mic_rounded,
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
                            child:
                                Text(p.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _projectId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text('Could not load projects',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('Language', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.s2),
              AiLanguageToggle(
                value: _language,
                onChanged: (v) => setState(() => _language = v),
              ),
              const SizedBox(height: AppSpacing.s6),
              _MicButton(
                listening: _listening,
                soundLevel: _soundLevel,
                enabled: _speechReady,
                onTap: _toggleListening,
              ),
              const SizedBox(height: AppSpacing.s3),
              Center(
                child: Text(
                  !_speechReady
                      ? 'Preparing microphone…'
                      : _listening
                          ? 'Listening… tap to stop'
                          : 'Tap the mic and start speaking',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              _TranscriptCard(
                transcript: _transcript,
                onClear: _transcript.isEmpty ? null : _clearTranscript,
              ),
              const SizedBox(height: AppSpacing.s6),
              FilledButton.icon(
                onPressed: (_generating || _transcript.trim().isEmpty)
                    ? null
                    : _generate,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generate report'),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s6),
                AiErrorState(message: _error!, onRetry: _generate),
              ],
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.s6),
                _VoiceReportPreview(result: _result!),
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

/// A large circular mic button that pulses with the live sound level.
class _MicButton extends StatelessWidget {
  final bool listening;
  final double soundLevel;
  final bool enabled;
  final VoidCallback onTap;

  const _MicButton({
    required this.listening,
    required this.soundLevel,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Map the (roughly 0..10) sound level to a small halo growth.
    final pulse = listening ? (soundLevel.clamp(0, 10) / 10) * 22 : 0.0;
    return Center(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 108 + pulse,
          height: 108 + pulse,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening
                ? AppColors.error.withValues(alpha: 0.12)
                : AppColors.infoLight,
          ),
          child: Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !enabled
                    ? AppColors.textDisabled
                    : listening
                        ? AppColors.error
                        : AppColors.primary,
                boxShadow: AppElevation.md,
              ),
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: AppColors.textOnPrimary,
                size: 34,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  final String transcript;
  final VoidCallback? onClear;

  const _TranscriptCard({required this.transcript, this.onClear});

  @override
  Widget build(BuildContext context) {
    final empty = transcript.trim().isEmpty;
    return Container(
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
            children: [
              const Icon(Icons.subject_rounded,
                  size: 18, color: AppColors.textHint),
              const SizedBox(width: AppSpacing.s2),
              Text('Transcript', style: AppTextStyles.titleSmall),
              const Spacer(),
              if (onClear != null)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          empty
              ? Text(
                  'Your spoken notes will appear here.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textHint),
                )
              : SelectableText(transcript, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _VoiceReportPreview extends StatelessWidget {
  final DailyReportResult result;
  const _VoiceReportPreview({required this.result});

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

  /// Copies the summary and explains how to paste it into WhatsApp — no
  /// share_plus dependency required.
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

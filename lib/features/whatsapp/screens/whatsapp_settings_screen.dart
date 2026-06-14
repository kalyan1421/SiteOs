import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/whatsapp_preferences.dart';
import '../data/models/whatsapp_recipient.dart';
import '../providers/whatsapp_provider.dart';
import '../widgets/recipient_tile.dart';
import '../widgets/whatsapp_status_card.dart';

/// WhatsApp settings: connection status, daily-report toggle, recipient
/// management, send hour, a "send test" action, and a recent-activity log.
///
/// Wrapped in PlanGuard(AppFeature.whatsapp) by the router.
class WhatsAppSettingsScreen extends ConsumerStatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  ConsumerState<WhatsAppSettingsScreen> createState() =>
      _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState
    extends ConsumerState<WhatsAppSettingsScreen> {
  /// Local working copy of the preferences, edited before saving.
  WhatsAppPreferences? _draft;
  bool _dirty = false;

  void _ensureDraft(WhatsAppPreferences source) {
    _draft ??= source;
  }

  void _updateDraft(WhatsAppPreferences next) {
    setState(() {
      _draft = next;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final ok =
        await ref.read(whatsAppControllerProvider.notifier).savePreferences(draft);
    if (!mounted) return;
    if (ok) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
      );
    } else {
      final err = ref.read(whatsAppControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: ${err ?? 'unknown error'}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _sendTest() async {
    final recipients = _draft?.recipients ?? const [];
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a recipient first to send a test.')),
      );
      return;
    }
    final target = await _pickTestRecipient(recipients);
    if (target == null) return;

    final error =
        await ref.read(whatsAppControllerProvider.notifier).sendTest(target.phone);
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test message sent to ${target.name}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Send failed: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<WhatsAppRecipient?> _pickTestRecipient(
      List<WhatsAppRecipient> recipients) {
    if (recipients.length == 1) {
      return Future.value(recipients.first);
    }
    return showModalBottomSheet<WhatsAppRecipient>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.xlR),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Text('Send test to…', style: AppTextStyles.titleMedium),
            ),
            for (final r in recipients)
              ListTile(
                leading: const Icon(Icons.send_rounded,
                    color: AppColors.primary),
                title: Text(r.name, style: AppTextStyles.titleSmall),
                subtitle: Text(r.phone, style: AppTextStyles.mono),
                onTap: () => Navigator.of(context).pop(r),
              ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(whatsAppConfigProvider);
    final prefsAsync = ref.watch(whatsAppPreferencesProvider);
    final controllerState = ref.watch(whatsAppControllerProvider);
    final busy = controllerState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Reports')),
      floatingActionButton: _dirty
          ? FloatingActionButton.extended(
              onPressed: busy ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
            )
          : null,
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(whatsAppPreferencesProvider),
        ),
        data: (prefs) {
          _ensureDraft(prefs);
          final draft = _draft!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            children: [
              // Connection status
              configAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (config) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s5),
                  child: WhatsAppStatusCard(config: config),
                ),
              ),

              // Daily report toggle
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: draft.dailyReportEnabled,
                      onChanged: (v) => _updateDraft(
                          draft.copyWith(dailyReportEnabled: v)),
                      title: Text('Daily progress report',
                          style: AppTextStyles.titleMedium),
                      subtitle: Text(
                        'Send a WhatsApp summary to recipients every evening.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    const Divider(height: AppSpacing.s6),
                    _SendHourRow(
                      sendHour: draft.sendHour,
                      enabled: draft.dailyReportEnabled,
                      onChanged: (h) =>
                          _updateDraft(draft.copyWith(sendHour: h)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s5),

              // Recipients
              _SectionHeader(
                title: 'Recipients',
                action: TextButton.icon(
                  onPressed: () => AddRecipientSheet.show(
                    context,
                    (r) => _updateDraft(draft.copyWith(
                        recipients: [...draft.recipients, r])),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              if (draft.recipients.isEmpty)
                _EmptyRecipients()
              else
                ...List.generate(draft.recipients.length, (i) {
                  final r = draft.recipients[i];
                  return RecipientTile(
                    recipient: r,
                    onRemove: () {
                      final next = [...draft.recipients]..removeAt(i);
                      _updateDraft(draft.copyWith(recipients: next));
                    },
                  );
                }),
              const SizedBox(height: AppSpacing.s5),

              // Send test
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _sendTest,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(busy ? 'Sending…' : 'Send test message'),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),

              // Activity log
              _SectionHeader(title: 'Recent activity'),
              const SizedBox(height: AppSpacing.s2),
              const _ActivityLog(),
              const SizedBox(height: AppSpacing.s12),
            ],
          );
        },
      ),
    );
  }
}

class _SendHourRow extends StatelessWidget {
  final int sendHour;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _SendHourRow({
    required this.sendHour,
    required this.enabled,
    required this.onChanged,
  });

  String _formatHour(int h) {
    final period = h < 12 ? 'AM' : 'PM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display:00 $period';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text('Send time (IST)', style: AppTextStyles.bodyMedium),
          ),
          DropdownButton<int>(
            value: sendHour,
            underline: const SizedBox.shrink(),
            onChanged: enabled
                ? (v) {
                    if (v != null) onChanged(v);
                  }
                : null,
            items: [
              for (var h = 0; h < 24; h++)
                DropdownMenuItem(
                  value: h,
                  child: Text(_formatHour(h), style: AppTextStyles.mono),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityLog extends ConsumerWidget {
  const _ActivityLog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(whatsAppLogsProvider);
    return logsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.s4),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Could not load activity.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.s5),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Center(
              child: Text(
                'No messages sent yet.',
                style: AppTextStyles.bodySmall,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final log in logs.take(10))
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s2),
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _StatusDot(sent: log.status.value == 'sent'),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.to, style: AppTextStyles.mono),
                          Text(
                            log.template,
                            style: AppTextStyles.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      log.status.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: log.status.value == 'sent'
                            ? AppColors.success
                            : (log.status.value == 'failed'
                                ? AppColors.error
                                : AppColors.textHint),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool sent;
  const _StatusDot({required this.sent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: sent ? AppColors.success : AppColors.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title.toUpperCase(), style: AppTextStyles.overline),
        if (action != null) action!,
      ],
    );
  }
}

class _EmptyRecipients extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Center(
        child: Text(
          'No recipients yet. Add one to receive reports.',
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textHint, size: 40),
            const SizedBox(height: AppSpacing.s4),
            Text(
              "Couldn't load WhatsApp settings.",
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

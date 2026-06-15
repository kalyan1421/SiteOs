import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/chat_message.dart';
import '../providers/ai_providers.dart';
import '../widgets/ai_widgets.dart';

/// AKS-79 — SiteOS Assistant chat. Answers questions about the company's own
/// data (projects, attendance, materials) in English or Hindi. All inference
/// runs server-side via the `ai-chat` Edge Function; history is persisted to
/// `ai_chat_messages` (RLS-scoped per company).
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  /// Quick-start prompts shown when the conversation is empty.
  static const _suggestions = <String>[
    'How many active projects do we have?',
    'What materials were received recently?',
    "What's today's attendance?",
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty) return;
    _inputController.clear();
    await ref.read(chatProvider.notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.clearChatHistoryConfirm),
          content: const Text(
              'This permanently deletes your assistant conversation.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.clear),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await ref.read(chatProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(chatProvider);

    // Auto-scroll as new messages arrive.
    ref.listen(chatProvider, (prev, next) {
      if (prev == null || next.messages.length != prev.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.siteOsAssistant),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AiLanguageToggle(
                  value: state.language,
                  onChanged: (v) =>
                      ref.read(chatProvider.notifier).setLanguage(v),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? _EmptyState(
                        suggestions: _suggestions,
                        onTap: _send,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        itemCount: state.messages.length,
                        itemBuilder: (context, i) =>
                            _MessageBubble(message: state.messages[i]),
                      ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
              child: Text(
                state.error!,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          _Composer(
            controller: _inputController,
            isSending: state.isSending,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _EmptyState({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s6),
      children: [
        const SizedBox(height: AppSpacing.s8),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary, size: 34),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(l10n.askAboutYourSites,
            style: AppTextStyles.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'The assistant answers from your company data only — projects, '
          'attendance and materials.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s6),
        ...suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: OutlinedButton(
              onPressed: () => onTap(s),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(AppSpacing.s4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 18),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(s,
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.left),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isUser ? AppColors.primary : AppColors.surface;
    final fg = isUser ? AppColors.textOnPrimary : AppColors.textPrimary;
    final radius = BorderRadius.only(
      topLeft: AppRadius.lgR,
      topRight: AppRadius.lgR,
      bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.sm),
      bottomRight: Radius.circular(isUser ? AppRadius.sm : AppRadius.lg),
    );

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s3),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: isUser ? null : Border.all(color: AppColors.border),
          boxShadow: isUser ? null : AppElevation.sm,
        ),
        child: message.isPending
            ? const _TypingIndicator()
            : SelectableText(
                message.content,
                style: AppTextStyles.bodyMedium.copyWith(color: fg),
              ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.s2),
        Text(l10n.thinking,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                enabled: !isSending,
                decoration: const InputDecoration(
                  hintText: 'Ask anything about your sites…',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            IconButton.filled(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textOnPrimary),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_client.dart';
import '../data/models/chat_message.dart';
import '../data/repositories/ai_repository.dart';

/// Singleton repository for all AI Edge Function calls.
final aiRepositoryProvider = Provider<AiRepository>((ref) => AiRepository());

/// A minimal project option for the daily-report / voice pickers.
/// Self-contained so the AI module doesn't depend on the projects feature.
class AiProjectOption {
  final String id;
  final String name;
  const AiProjectOption({required this.id, required this.name});
}

/// Lightweight list of the company's projects for selection dropdowns.
/// Reads under RLS, so it only ever returns the caller's company projects.
final aiProjectsProvider =
    FutureProvider<List<AiProjectOption>>((ref) async {
  try {
    final rows = await supabase
        .from('projects')
        .select('id, name')
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .whereType<Map>()
        .map((e) => AiProjectOption(
              id: (e['id'] ?? '').toString(),
              name: (e['name'] ?? 'Untitled project').toString(),
            ))
        .where((p) => p.id.isNotEmpty)
        .toList();
  } catch (e) {
    logger.w('aiProjectsProvider failed: $e');
    return const [];
  }
});

// ── Chat state ────────────────────────────────────────────────────────────

class ChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final bool isLoadingHistory;
  final String language; // 'en' | 'hi'
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isSending = false,
    this.isLoadingHistory = false,
    this.language = 'en',
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    bool? isLoadingHistory,
    String? language,
    String? error,
    bool clearError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isSending: isSending ?? this.isSending,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        language: language ?? this.language,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final AiRepository _repo;

  ChatNotifier(this._repo) : super(const ChatState()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    state = state.copyWith(isLoadingHistory: true);
    final history = await _repo.loadChatHistory();
    state = state.copyWith(messages: history, isLoadingHistory: false);
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }

  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.isSending) return;

    final userMsg = ChatMessage(role: ChatRole.user, content: question);
    final pending = ChatMessage(
      role: ChatRole.assistant,
      content: '',
      isPending: true,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg, pending],
      isSending: true,
      clearError: true,
    );

    try {
      final answer = await _repo.askAssistant(
        question: question,
        language: state.language,
      );
      final updated = [...state.messages];
      // Replace the pending bubble with the real answer.
      final idx = updated.lastIndexWhere((m) => m.isPending);
      if (idx != -1) {
        updated[idx] = updated[idx]
            .copyWith(content: answer, isPending: false);
      }
      state = state.copyWith(messages: updated, isSending: false);
    } catch (e) {
      final updated = [...state.messages]
        ..removeWhere((m) => m.isPending);
      state = state.copyWith(
        messages: updated,
        isSending: false,
        error: e.toString(),
      );
    }
  }

  Future<void> clear() async {
    await _repo.clearChatHistory();
    state = state.copyWith(messages: const []);
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(aiRepositoryProvider));
});

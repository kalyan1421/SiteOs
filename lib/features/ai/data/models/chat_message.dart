/// One chat turn in the AI assistant conversation.
enum ChatRole { user, assistant }

class ChatMessage {
  final String? id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  /// Local-only flag: an assistant bubble that is still being fetched.
  final bool isPending;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.isPending = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == ChatRole.user;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String?,
        role: (json['role'] as String?) == 'assistant'
            ? ChatRole.assistant
            : ChatRole.user,
        content: (json['content'] ?? '').toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    bool? isPending,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        role: role ?? this.role,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        isPending: isPending ?? this.isPending,
      );
}

import 'package:uuid/uuid.dart';

import 'chat_message.dart';

/// A single saved conversation thread with Vyra. The chat used to be one
/// ever-growing rolling log; conversations let the user keep, revisit and
/// manage distinct chats (issue #8). Persisted to Hive as a plain map (no
/// codegen) so history survives restarts.
class ChatConversation {
  final String id;

  /// Optional explicit title. When empty, [displayTitle] derives one from the
  /// first user message.
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatConversation({
    String? id,
    this.title = '',
    this.messages = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// A brand-new conversation seeded with Vyra's greeting.
  factory ChatConversation.fresh(ChatMessage greeting) =>
      ChatConversation(messages: [greeting]);

  /// Folds the legacy single rolling history into one conversation so existing
  /// users don't lose their chat when upgrading. [messages] must be non-empty.
  factory ChatConversation.fromMessages(List<ChatMessage> messages) =>
      ChatConversation(
        messages: messages,
        createdAt: messages.first.timestamp,
        updatedAt: messages.last.timestamp,
      );

  bool get isEmpty => messages.isEmpty;
  int get messageCount => messages.length;

  /// A human-friendly title: the explicit title, else the first thing the user
  /// said, else a sensible default.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    for (final m in messages) {
      if (m.isUser && m.text.trim().isNotEmpty) {
        return _truncate(m.text.trim(), 40);
      }
    }
    return 'New chat';
  }

  /// A one-line preview of the latest message for the history list.
  String get preview {
    for (final m in messages.reversed) {
      if (m.text.trim().isNotEmpty) {
        final who = m.isUser ? 'You: ' : '';
        return _truncate('$who${m.text.trim()}', 80);
      }
    }
    return 'No messages yet';
  }

  ChatConversation addMessage(ChatMessage message) =>
      copyWith(messages: [...messages, message]);

  ChatConversation touch() => copyWith(updatedAt: DateTime.now());

  ChatConversation copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) =>
      ChatConversation(
        id: id,
        title: title ?? this.title,
        messages: messages ?? this.messages,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Serializes the conversation, keeping only the most recent [maxMessages]
  /// so a very long chat can't grow Hive without bound.
  Map<String, dynamic> toMap({int maxMessages = 200}) {
    final msgs = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'messages': [for (final m in msgs) m.toMap()],
    };
  }

  factory ChatConversation.fromMap(Map map) {
    final msgs = <ChatMessage>[];
    final raw = map['messages'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) msgs.add(ChatMessage.fromMap(e));
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return ChatConversation(
      id: map['id'] as String?,
      title: (map['title'] as String?) ?? '',
      messages: msgs,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as int?) ?? now,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as int?) ?? now,
      ),
    );
  }

  static String _truncate(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n).trimRight()}…';
}

import 'package:uuid/uuid.dart';

import '../../../avatar/models/avatar_emotion.dart';

enum ChatRole { user, vyra }

/// A single message in the conversation. Stored in Hive as a plain map (no
/// codegen) so history survives restarts.
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final AvatarEmotion emotion; // meaningful for Vyra's messages
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    String? id,
    required this.role,
    required this.text,
    this.emotion = AvatarEmotion.neutral,
    DateTime? timestamp,
    this.isError = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == ChatRole.user;

  factory ChatMessage.user(String text) =>
      ChatMessage(role: ChatRole.user, text: text);

  factory ChatMessage.vyra(
    String text, {
    AvatarEmotion emotion = AvatarEmotion.neutral,
    bool isError = false,
  }) =>
      ChatMessage(
        role: ChatRole.vyra,
        text: text,
        emotion: emotion,
        isError: isError,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role.name,
        'text': text,
        'emotion': emotion.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isError': isError,
      };

  factory ChatMessage.fromMap(Map map) => ChatMessage(
        id: map['id'] as String?,
        role: ChatRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => ChatRole.vyra,
        ),
        text: (map['text'] as String?) ?? '',
        emotion: AvatarEmotion.fromTag(map['emotion'] as String?),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        ),
        isError: (map['isError'] as bool?) ?? false,
      );
}

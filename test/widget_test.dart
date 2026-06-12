import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/features/avatar/models/avatar_emotion.dart';
import 'package:vyra/features/chat/data/models/chat_message.dart';

void main() {
  group('AvatarEmotion.fromTag', () {
    test('parses known tags case-insensitively', () {
      expect(AvatarEmotion.fromTag('happy'), AvatarEmotion.happy);
      expect(AvatarEmotion.fromTag('EXCITED'), AvatarEmotion.excited);
      expect(AvatarEmotion.fromTag(' caring '), AvatarEmotion.caring);
    });

    test('falls back to neutral for unknown or null tags', () {
      expect(AvatarEmotion.fromTag(null), AvatarEmotion.neutral);
      expect(AvatarEmotion.fromTag('banana'), AvatarEmotion.neutral);
    });
  });

  group('ChatMessage', () {
    test('round-trips through a Hive map', () {
      final message =
          ChatMessage.vyra('Hello there', emotion: AvatarEmotion.happy);
      final restored = ChatMessage.fromMap(message.toMap());

      expect(restored.id, message.id);
      expect(restored.text, 'Hello there');
      expect(restored.role, ChatRole.vyra);
      expect(restored.emotion, AvatarEmotion.happy);
      expect(restored.isUser, isFalse);
    });

    test('user factory marks the message as from the user', () {
      final message = ChatMessage.user('Hi Vyra');
      expect(message.isUser, isTrue);
      expect(message.role, ChatRole.user);
    });
  });
}

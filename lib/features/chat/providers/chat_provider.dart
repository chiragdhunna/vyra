import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/ai/gemini_service.dart';
import '../../../services/service_providers.dart';
import '../../avatar/models/avatar_emotion.dart';
import '../../avatar/providers/avatar_provider.dart';
import '../../voice/providers/voice_provider.dart';
import '../data/models/chat_message.dart';

final geminiServiceProvider =
    Provider<GeminiService>((ref) => GeminiService.instance);

@immutable
class ChatState {
  final List<ChatMessage> messages;
  final bool isResponding;

  const ChatState({this.messages = const [], this.isResponding = false});

  ChatState copyWith({List<ChatMessage>? messages, bool? isResponding}) =>
      ChatState(
        messages: messages ?? this.messages,
        isResponding: isResponding ?? this.isResponding,
      );
}

/// Orchestrates the conversation: persists history to Hive, talks to Gemini,
/// and pushes emotion/activity changes to the avatar so Vyra's face reacts.
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState()) {
    _restore();
  }

  final Ref _ref;
  static const String _historyKey = 'history';
  static const int _maxStored = 200;

  GeminiService get _gemini => _ref.read(geminiServiceProvider);
  AvatarController get _avatar => _ref.read(avatarControllerProvider.notifier);

  void _restore() {
    final box = _ref.read(storageServiceProvider).chatBox;
    final raw = box.get(_historyKey);
    if (raw is List && raw.isNotEmpty) {
      final messages = raw
          .whereType<Map>()
          .map(ChatMessage.fromMap)
          .toList(growable: true);
      state = state.copyWith(messages: messages);
      _gemini.seedHistory([
        for (final m in messages) (isUser: m.isUser, text: m.text),
      ]);
    } else {
      _greet();
    }
  }

  void _greet() {
    final name = _ref.read(storageServiceProvider).userName;
    final hi = name.isEmpty ? 'Hey there' : 'Hey $name';
    final greeting = ChatMessage.vyra(
      "$hi! I'm Vyra. Ask me anything, or just tell me how your day's going. 💜",
      emotion: AvatarEmotion.happy,
    );
    state = state.copyWith(messages: [greeting]);
    _avatar.react(AvatarEmotion.happy);
    _persist();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isResponding) return;

    final userMsg = ChatMessage.user(trimmed);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isResponding: true,
    );
    _avatar.setActivity(AvatarActivity.thinking);
    _persist();

    final reply = await _gemini.send(trimmed);
    final emotion = AvatarEmotion.fromTag(reply.emotion);
    final vyraMsg = ChatMessage.vyra(
      reply.text,
      emotion: emotion,
      isError: reply.isError,
    );

    state = state.copyWith(
      messages: [...state.messages, vyraMsg],
      isResponding: false,
    );
    // React with the emotion; if TTS is on, the voice layer then flips the
    // avatar to "speaking" while it reads the reply aloud.
    _avatar.react(emotion, activity: AvatarActivity.idle);
    _persist();
    if (!reply.isError) {
      unawaited(_ref.read(voiceControllerProvider.notifier).speak(reply.text));
    }
  }

  void clear() {
    state = const ChatState();
    _gemini.resetSession();
    _avatar.react(AvatarEmotion.neutral, activity: AvatarActivity.idle);
    _ref.read(storageServiceProvider).chatBox.delete(_historyKey);
    _greet();
  }

  void _persist() {
    final box = _ref.read(storageServiceProvider).chatBox;
    final toStore = state.messages
        .take(_maxStored)
        .map((m) => m.toMap())
        .toList(growable: false);
    box.put(_historyKey, toStore);
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(ref),
);

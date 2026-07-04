import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../services/ai/ai_engine.dart';
import '../../../services/ai/backend_ai_service.dart';
import '../../../services/ai/gemini_service.dart';
import '../../../services/service_providers.dart';
import '../../avatar/models/avatar_emotion.dart';
import '../../avatar/providers/avatar_provider.dart';
import '../../voice/providers/voice_provider.dart';
import '../data/models/chat_conversation.dart';
import '../data/models/chat_message.dart';

final geminiServiceProvider =
    Provider<GeminiService>((ref) => GeminiService.instance);

/// Vyra's active brain. With VYRA_BACKEND_URL set, chat routes through the
/// vyra-backend on your LAN (which picks Ollama or a cloud model from ITS
/// .env); otherwise the original direct-Gemini mode is used.
final aiEngineProvider = Provider<AiEngine>(
  (ref) => Env.hasBackend
      ? BackendAiService()
      : ref.read(geminiServiceProvider),
);

@immutable
class ChatState {
  /// All saved conversations, most-recently-updated first.
  final List<ChatConversation> conversations;

  /// The conversation currently shown in the chat screen.
  final String? activeId;
  final bool isResponding;

  const ChatState({
    this.conversations = const [],
    this.activeId,
    this.isResponding = false,
  });

  ChatConversation? get active {
    for (final c in conversations) {
      if (c.id == activeId) return c;
    }
    return null;
  }

  /// The active conversation's messages — the existing surface the chat UI,
  /// vision screen and home hub all read.
  List<ChatMessage> get messages => active?.messages ?? const [];

  ChatState copyWith({
    List<ChatConversation>? conversations,
    String? activeId,
    bool? isResponding,
  }) =>
      ChatState(
        conversations: conversations ?? this.conversations,
        activeId: activeId ?? this.activeId,
        isResponding: isResponding ?? this.isResponding,
      );
}

/// Orchestrates the conversation: persists a list of saved conversations to
/// Hive, talks to Gemini for the active one, and pushes emotion/activity
/// changes to the avatar so Vyra's face reacts.
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState()) {
    _restore();
  }

  final Ref _ref;

  static const String _convosKey = 'conversations';
  static const String _activeKey = 'active_id';
  static const String _legacyKey = 'history'; // old single rolling log
  static const int _maxConversations = 40;
  static const int _maxMessagesStored = 200;

  AiEngine get _ai => _ref.read(aiEngineProvider);
  AvatarController get _avatar => _ref.read(avatarControllerProvider.notifier);

  void _restore() {
    final box = _ref.read(storageServiceProvider).chatBox;

    final convos = <ChatConversation>[];
    final rawConvos = box.get(_convosKey);
    if (rawConvos is List) {
      for (final e in rawConvos) {
        if (e is Map) convos.add(ChatConversation.fromMap(e));
      }
    }

    // One-time migration: fold the legacy rolling history into a conversation
    // so upgrading users keep their chat.
    if (convos.isEmpty) {
      final legacy = box.get(_legacyKey);
      if (legacy is List && legacy.isNotEmpty) {
        final msgs =
            legacy.whereType<Map>().map(ChatMessage.fromMap).toList();
        if (msgs.isNotEmpty) convos.add(ChatConversation.fromMessages(msgs));
      }
    }
    box.delete(_legacyKey); // legacy folded in (or absent) — safe to drop

    if (convos.isEmpty) {
      _startFresh(persist: true);
      return;
    }

    convos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final storedActive = box.get(_activeKey) as String?;
    final activeId = convos.any((c) => c.id == storedActive)
        ? storedActive!
        : convos.first.id;
    state = ChatState(conversations: convos, activeId: activeId);
    _seedGeminiFromActive();
  }

  ChatMessage _greetingMessage() {
    final name = _ref.read(storageServiceProvider).userName;
    final hi = name.isEmpty ? 'Hey there' : 'Hey $name';
    return ChatMessage.vyra(
      "$hi! I'm Vyra. Ask me anything, or just tell me how your day's going. 💜",
      emotion: AvatarEmotion.happy,
    );
  }

  /// Creates a brand-new active conversation with a greeting.
  void _startFresh({bool persist = false}) {
    final convo = ChatConversation.fresh(_greetingMessage());
    state = state.copyWith(
      conversations: [convo, ...state.conversations],
      activeId: convo.id,
    );
    _ai.resetSession();
    _avatar.react(AvatarEmotion.happy);
    if (persist) _persist();
  }

  void _seedGeminiFromActive() {
    _ai.seedHistory([
      for (final m in state.messages) (isUser: m.isUser, text: m.text),
    ]);
  }

  /// Applies a transform to the active conversation, then moves it to the front
  /// of the list (most-recent-first ordering for the history screen).
  void _updateActive(ChatConversation Function(ChatConversation) transform) {
    final id = state.activeId;
    if (id == null) return;
    final rest = <ChatConversation>[];
    ChatConversation? changed;
    for (final c in state.conversations) {
      if (c.id == id) {
        changed = transform(c).touch();
      } else {
        rest.add(c);
      }
    }
    if (changed == null) return;
    state = state.copyWith(conversations: [changed, ...rest]);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isResponding) return;
    if (state.active == null) _startFresh();

    final userMsg = ChatMessage.user(trimmed);
    _updateActive((c) => c.addMessage(userMsg));
    state = state.copyWith(isResponding: true);
    _avatar.setActivity(AvatarActivity.thinking);
    _persist();

    final reply = await _ai.send(trimmed);
    final emotion = AvatarEmotion.fromTag(reply.emotion);
    final vyraMsg = ChatMessage.vyra(
      reply.text,
      emotion: emotion,
      isError: reply.isError,
    );

    _updateActive((c) => c.addMessage(vyraMsg));
    state = state.copyWith(isResponding: false);
    // React with the emotion; if TTS is on, the voice layer then flips the
    // avatar to "speaking" while it reads the reply aloud.
    _avatar.react(emotion, activity: AvatarActivity.idle);
    _persist();
    if (!reply.isError) {
      unawaited(_ref.read(voiceControllerProvider.notifier).speak(reply.text));
    }
  }

  /// Starts a new conversation; the current one stays saved in history.
  void newConversation() => _startFresh(persist: true);

  /// Switches the active conversation and re-seeds Gemini with its context.
  void openConversation(String id) {
    if (id == state.activeId) return;
    if (!state.conversations.any((c) => c.id == id)) return;
    state = state.copyWith(activeId: id);
    _ref.read(storageServiceProvider).chatBox.put(_activeKey, id);
    _ai.resetSession();
    _seedGeminiFromActive();
    // Reflect that conversation's last mood on the avatar.
    final msgs = state.messages;
    final lastEmotion = msgs.isEmpty ? AvatarEmotion.neutral : msgs.last.emotion;
    _avatar.react(lastEmotion, activity: AvatarActivity.idle);
  }

  /// Deletes a conversation. If it was active, falls back to the most recent
  /// remaining one (or a fresh chat when none remain).
  void deleteConversation(String id) {
    final remaining = state.conversations.where((c) => c.id != id).toList();
    final wasActive = state.activeId == id;
    if (remaining.isEmpty) {
      state = const ChatState();
      _startFresh(persist: true);
      return;
    }
    state = state.copyWith(
      conversations: remaining,
      activeId: wasActive ? remaining.first.id : state.activeId,
    );
    _persist();
    if (wasActive) {
      _ai.resetSession();
      _seedGeminiFromActive();
    }
  }

  /// "Clear chat history" — wipes every saved conversation and starts over.
  void clear() {
    final box = _ref.read(storageServiceProvider).chatBox;
    box.delete(_convosKey);
    box.delete(_activeKey);
    box.delete(_legacyKey);
    state = const ChatState();
    _ai.resetSession();
    _avatar.react(AvatarEmotion.neutral, activity: AvatarActivity.idle);
    _startFresh(persist: true);
  }

  void _persist() {
    final box = _ref.read(storageServiceProvider).chatBox;
    final convos = state.conversations.take(_maxConversations).toList();
    box.put(_convosKey, [
      for (final c in convos) c.toMap(maxMessages: _maxMessagesStored),
    ]);
    if (state.activeId != null) box.put(_activeKey, state.activeId);
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(ref),
);

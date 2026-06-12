import 'package:google_generative_ai/google_generative_ai.dart';

import '../../core/config/env.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

/// A parsed reply from Gemini: the user-facing [text] with the hidden
/// `[emotion: X]` tag stripped out, plus the [emotion] name for the avatar.
class GeminiReply {
  final String text;
  final String emotion;
  final bool isError;

  const GeminiReply(this.text, this.emotion, {this.isError = false});
}

/// Vyra's AI engine, powered by Google Gemini (replaces OpenAI GPT from the
/// original spec). Keeps a single multi-turn [ChatSession] so context carries
/// across the conversation, and degrades gracefully when no API key is set.
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  GenerativeModel? _model;
  ChatSession? _chat;

  static final RegExp _emotionTag =
      RegExp(r'\[emotion:\s*([a-zA-Z]+)\s*\]', caseSensitive: false);

  bool get isConfigured => Env.hasGeminiKey;

  GenerativeModel _buildModel() => GenerativeModel(
        model: Env.geminiModel,
        apiKey: Env.geminiApiKey,
        systemInstruction: Content.system(AppConstants.vyraSystemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.9,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
      );

  void _ensureModel() {
    if (!Env.hasGeminiKey) return;
    _model ??= _buildModel();
    _chat ??= _model!.startChat();
  }

  /// Rebuilds the chat session seeded with prior history so context survives an
  /// app restart. [history] is oldest-first.
  void seedHistory(List<({bool isUser, String text})> history) {
    if (!Env.hasGeminiKey) return;
    _model ??= _buildModel();
    _chat = _model!.startChat(
      history: [
        for (final m in history)
          if (m.isUser)
            Content.text(m.text)
          else
            Content.model([TextPart(m.text)]),
      ],
    );
  }

  /// Sends a user message and returns Vyra's parsed reply.
  Future<GeminiReply> send(String message) async {
    if (!Env.hasGeminiKey) {
      return const GeminiReply(
        "I'd love to chat! I just need a Gemini API key to think with. "
        "Pop your key into the .env file as GEMINI_API_KEY and restart me. 💜",
        'caring',
        isError: true,
      );
    }
    _ensureModel();
    try {
      final response = await _chat!.sendMessage(Content.text(message));
      final raw = response.text ?? '';
      if (raw.trim().isEmpty) {
        return const GeminiReply(
          "I went quiet there for a second — could you say that again?",
          'thinking',
        );
      }
      return _parse(raw);
    } catch (e, st) {
      AppLogger.e('Gemini request failed', error: e, stackTrace: st, tag: 'Gemini');
      return const GeminiReply(
        "Hmm, I couldn't reach my brain just now. Mind trying again in a moment?",
        'sad',
        isError: true,
      );
    }
  }

  GeminiReply _parse(String raw) {
    final match = _emotionTag.firstMatch(raw);
    final emotion = match?.group(1)?.toLowerCase() ?? 'neutral';
    final text = raw.replaceAll(_emotionTag, '').trim();
    return GeminiReply(text.isEmpty ? '…' : text, emotion);
  }

  /// Clears the conversation context (used by "clear chat").
  void resetSession() {
    _chat = _model?.startChat();
  }
}

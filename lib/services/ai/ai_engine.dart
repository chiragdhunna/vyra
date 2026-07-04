/// The contract for Vyra's brain, whoever provides it.
///
/// Two implementations exist:
///  * [GeminiService] — the original standalone mode: the phone talks to
///    Google Gemini directly (needs GEMINI_API_KEY in the app's .env).
///  * [BackendAiService] — routes through a `vyra-backend` server on the
///    LAN, which picks the model (local Ollama or cloud) from ITS .env and
///    keeps API keys off the phone entirely.
///
/// `aiEngineProvider` (see chat_provider.dart) selects one at startup based
/// on VYRA_BACKEND_URL.
library;

/// A parsed reply: user-facing [text] with the hidden `[emotion: X]` tag
/// already stripped, plus the [emotion] name driving the avatar.
class AiReply {
  final String text;
  final String emotion;
  final bool isError;

  const AiReply(this.text, this.emotion, {this.isError = false});
}

abstract class AiEngine {
  /// Whether this engine has what it needs (key / URL) to actually think.
  bool get isConfigured;

  /// Human-readable description of the active brain, for the UI.
  String get label;

  /// Sends a user message (with whatever context the engine keeps) and
  /// returns the parsed reply. Must never throw — errors come back as an
  /// [AiReply] with `isError: true` and a friendly text.
  Future<AiReply> send(String message);

  /// Rebuilds internal context from persisted history (oldest first).
  void seedHistory(List<({bool isUser, String text})> history);

  /// Clears conversation context (new chat / clear history).
  void resetSession();
}

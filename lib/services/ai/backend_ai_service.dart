import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import '../../core/utils/app_logger.dart';
import 'ai_engine.dart';

/// Vyra's brain when a `vyra-backend` server is configured.
///
/// Talks to `POST /chat` — a stateless endpoint — so this service keeps a
/// local mirror of the conversation (seeded from Hive on restore) and sends
/// the recent window with every request. The backend owns the personality
/// prompt and the emotion parsing; we receive clean `{text, emotion}`.
class BackendAiService implements AiEngine {
  BackendAiService({http.Client? client, String? baseUrl, String? apiKey})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Env.backendUrl,
        _apiKey = apiKey ?? Env.backendApiKey;

  final http.Client _client;
  final String _baseUrl;
  final String _apiKey;

  static const int _maxWindow = 24;
  static const Duration _timeout = Duration(seconds: 150);

  final List<Map<String, String>> _history = [];

  @override
  bool get isConfigured => _baseUrl.isNotEmpty;

  @override
  String get label => 'Backend';

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_apiKey.isNotEmpty) 'X-Vyra-Key': _apiKey,
      };

  @override
  Future<AiReply> send(String message) async {
    if (!isConfigured) {
      return const AiReply(
        "I can't find my backend! Set VYRA_BACKEND_URL in the .env and "
        'restart me. 💜',
        'caring',
        isError: true,
      );
    }
    _history.add({'role': 'user', 'content': message});
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: _headers,
            body: jsonEncode({
              'messages': _window(),
            }),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        AppLogger.w(
          'Backend /chat -> ${response.statusCode}: ${response.body}',
          tag: 'Backend',
        );
        _history.removeLast(); // let them retry the same message
        return AiReply(
          _friendlyHttpError(response.statusCode),
          'sad',
          isError: true,
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final text = (data['text'] as String?)?.trim() ?? '';
      final emotion = (data['emotion'] as String?) ?? 'neutral';
      if (text.isEmpty) {
        return const AiReply(
          'I went quiet there for a second — could you say that again?',
          'thinking',
        );
      }
      _history.add({'role': 'assistant', 'content': text});
      return AiReply(text, emotion);
    } on TimeoutException {
      _history.removeLast();
      return const AiReply(
        'My brain is taking too long — is the backend (and its model) up '
        'and on the same Wi-Fi?',
        'sad',
        isError: true,
      );
    } catch (e, st) {
      AppLogger.e('Backend chat failed', error: e, stackTrace: st, tag: 'Backend');
      _history.removeLast();
      return const AiReply(
        "I couldn't reach my backend just now. Check it's running and that "
        "we're on the same Wi-Fi?",
        'sad',
        isError: true,
      );
    }
  }

  List<Map<String, String>> _window() {
    final start = _history.length > _maxWindow ? _history.length - _maxWindow : 0;
    return _history.sublist(start);
  }

  String _friendlyHttpError(int status) {
    if (status == 401) {
      return 'The backend rejected my key — make sure VYRA_BACKEND_API_KEY '
          'matches VYRA_API_KEY on the server.';
    }
    if (status == 502) {
      return "The backend couldn't reach its model — is Ollama running / "
          'is the cloud key set on the server?';
    }
    return 'The backend had a hiccup (HTTP $status). Mind trying again?';
  }

  @override
  void seedHistory(List<({bool isUser, String text})> history) {
    _history
      ..clear()
      ..addAll([
        for (final m in history)
          {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
      ]);
  }

  @override
  void resetSession() => _history.clear();
}

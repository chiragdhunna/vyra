import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Type-safe, crash-proof access to values loaded from the `.env` file.
///
/// Every getter falls back to a sensible default if `.env` was never loaded or
/// the key is missing, so the app never throws just because a key is absent —
/// instead, features degrade gracefully (e.g. the chat shows a friendly
/// "add your Gemini key" message).
class Env {
  Env._();

  static String _get(String key, {String fallback = ''}) {
    try {
      final value = dotenv.maybeGet(key);
      if (value == null || value.trim().isEmpty) return fallback;
      return value.trim();
    } catch (_) {
      return fallback;
    }
  }

  // --- Gemini ---
  static String get geminiApiKey => _get('GEMINI_API_KEY');
  // Default kept current: gemini-1.5-flash and gemini-2.0-flash were retired
  // by Google in 2025–2026. gemini-2.5-flash is fast and free-tier eligible.
  static String get geminiModel =>
      _get('GEMINI_MODEL', fallback: 'gemini-2.5-flash');
  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;

  // --- vyra-backend (optional companion brain) ---
  // e.g. http://192.168.1.42:8000 — the machine running vyra-backend on the
  // same Wi-Fi. When set, chat + the companion screen route through it
  // (Ollama or cloud, chosen by the BACKEND's .env) instead of calling
  // Gemini directly from the phone.
  static String get backendUrl {
    final raw = _get('VYRA_BACKEND_URL');
    if (raw.isEmpty) return '';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Shared secret matching VYRA_API_KEY on the backend (optional).
  static String get backendApiKey => _get('VYRA_BACKEND_API_KEY');
  static bool get hasBackend => backendUrl.isNotEmpty;

  /// ws:// (or wss://) form of [backendUrl] for the realtime socket.
  static String get backendWsUrl {
    final url = backendUrl;
    if (url.isEmpty) return '';
    if (url.startsWith('https://')) return 'wss://${url.substring(8)}';
    if (url.startsWith('http://')) return 'ws://${url.substring(7)}';
    return url;
  }

  // --- Weather ---
  static String get openWeatherApiKey => _get('OPENWEATHER_API_KEY');
  static bool get hasWeatherKey => openWeatherApiKey.isNotEmpty;

  // --- Firebase (optional) ---
  static String get firebaseApiKey => _get('FIREBASE_API_KEY');
  static String get firebaseAppId => _get('FIREBASE_APP_ID');
  static String get firebaseMessagingSenderId =>
      _get('FIREBASE_MESSAGING_SENDER_ID');
  static String get firebaseProjectId => _get('FIREBASE_PROJECT_ID');
  static String get firebaseStorageBucket => _get('FIREBASE_STORAGE_BUCKET');

  static bool get hasFirebase =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}

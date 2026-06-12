import 'package:flutter/foundation.dart';

/// Minimal logger that only prints in debug/profile builds and stays silent in
/// release. Keeps log output tidy and prefixed so it's easy to filter.
class AppLogger {
  AppLogger._();

  static void d(Object? message, {String tag = 'Vyra'}) {
    if (kReleaseMode) return;
    debugPrint('💜 [$tag] $message');
  }

  static void w(Object? message, {String tag = 'Vyra'}) {
    if (kReleaseMode) return;
    debugPrint('⚠️ [$tag] $message');
  }

  static void e(Object? message, {Object? error, StackTrace? stackTrace, String tag = 'Vyra'}) {
    if (kReleaseMode) return;
    debugPrint('❌ [$tag] $message${error != null ? ' | $error' : ''}');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}

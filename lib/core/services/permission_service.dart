import 'package:permission_handler/permission_handler.dart';

/// Serializes runtime permission requests.
///
/// Android can only present one permission dialog at a time. Vyra asks for two
/// permissions eagerly at startup — microphone (for voice, via speech_to_text)
/// and location (for weather) — and because every tab is built at once in the
/// home `IndexedStack`, those requests fired concurrently. One dialog was
/// dropped (so mic wasn't asked on first launch) and the in‑flight request's
/// Future was left unresolved, which is why the weather card hung on "loading"
/// until the app was restarted.
///
/// Routing every request through a single chain guarantees they run one at a
/// time: each dialog is shown in turn and each Future completes.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  Future<void> _chain = Future<void>.value();

  /// Requests [permission], queued behind any in‑flight request. Permissions
  /// that are already granted short‑circuit without showing a dialog.
  Future<PermissionStatus> request(Permission permission) {
    final next = _chain.then((_) async {
      if (await permission.isGranted) return PermissionStatus.granted;
      return permission.request();
    });
    // Keep the chain alive regardless of how any individual request resolves.
    _chain = next.then((_) {}, onError: (_) {});
    return next;
  }
}

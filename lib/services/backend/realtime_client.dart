import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/env.dart';
import '../../core/utils/app_logger.dart';
import 'realtime_events.dart';

/// Connection lifecycle as seen by the UI.
enum RealtimeStatus { disconnected, connecting, connected }

/// The app's side of the `/realtime` websocket: connects, hands parsed
/// [RealtimeEvent]s to a listener, sends mic audio + control events, and
/// reconnects with backoff if the backend drops (server restart, Wi-Fi
/// blip) — the companion quietly comes back to life.
class RealtimeClient {
  RealtimeClient({
    required this.onEvent,
    required this.onStatus,
    String? wsUrl,
    String? apiKey,
  })  : _wsUrl = wsUrl ?? Env.backendWsUrl,
        _apiKey = apiKey ?? Env.backendApiKey;

  final void Function(RealtimeEvent event) onEvent;
  final void Function(RealtimeStatus status) onStatus;
  final String _wsUrl;
  final String _apiKey;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _attempt = 0;
  bool _closed = false;

  String? _userName;
  bool _greet = true;
  bool _clientStt = false;

  bool get isConfigured => _wsUrl.isNotEmpty;
  RealtimeStatus _status = RealtimeStatus.disconnected;
  RealtimeStatus get status => _status;

  Future<void> connect({
    String? userName,
    bool greet = true,
    bool clientStt = false,
  }) async {
    _userName = userName;
    _greet = greet;
    _clientStt = clientStt;
    _closed = false;
    await _open(fresh: true);
  }

  Future<void> _open({bool fresh = false}) async {
    if (_closed || !isConfigured) return;
    if (fresh) _attempt = 0;
    _setStatus(RealtimeStatus.connecting);
    final uri = Uri.parse(
      _apiKey.isEmpty
          ? '$_wsUrl/realtime'
          : '$_wsUrl/realtime?key=${Uri.encodeQueryComponent(_apiKey)}',
    );
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      channel.sink.add(ClientEvents.sessionStart(
        userName: _userName,
        greet: _greet,
        clientStt: _clientStt,
      ));
      _subscription = channel.stream.listen(
        _onFrame,
        onDone: _onClosed,
        onError: (Object e) {
          AppLogger.w('Realtime socket error: $e', tag: 'Realtime');
          _onClosed();
        },
        cancelOnError: true,
      );
      _attempt = 0;
      _setStatus(RealtimeStatus.connected);
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _send(ClientEvents.ping());
      });
    } catch (e) {
      AppLogger.w('Realtime connect failed: $e', tag: 'Realtime');
      _onClosed();
    }
  }

  void _onFrame(dynamic frame) {
    if (frame is! String) return; // server never sends binary today
    final event = RealtimeEvent.decode(frame);
    if (event != null) onEvent(event);
  }

  void _onClosed() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    if (_closed) return;
    _setStatus(RealtimeStatus.disconnected);
    // Backoff: 1s, 2s, 4s… capped at 15s. Keeps trying forever — the
    // backend may simply not be started yet.
    final delay = Duration(
      milliseconds: (1000 * (1 << _attempt)).clamp(1000, 15000),
    );
    if (_attempt < 10) _attempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _open);
  }

  void _setStatus(RealtimeStatus status) {
    if (_status == status) return;
    _status = status;
    onStatus(status);
  }

  void _send(String json) {
    try {
      _channel?.sink.add(json);
    } catch (e) {
      AppLogger.w('Realtime send failed: $e', tag: 'Realtime');
    }
  }

  /// Raw PCM16 mono @16 kHz mic audio.
  void sendAudio(Uint8List pcm) {
    if (_status != RealtimeStatus.connected) return;
    try {
      _channel?.sink.add(pcm);
    } catch (_) {}
  }

  void sendVision({required bool present, required bool smiling}) =>
      _send(ClientEvents.visionState(present: present, smiling: smiling));

  void sendUserText(String text) => _send(ClientEvents.userText(text));

  void sendTtsState({required bool playing}) =>
      _send(ClientEvents.ttsState(playing: playing));

  void sendMicState({required bool muted}) =>
      _send(ClientEvents.micState(muted: muted));

  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _setStatus(RealtimeStatus.disconnected);
  }
}

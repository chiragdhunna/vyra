import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vyra/features/avatar/assets/anime_sprites.dart';
import 'package:vyra/features/avatar/models/avatar_emotion.dart';
import 'package:vyra/features/avatar/presentation/widgets/avatar_painter.dart';
import 'package:vyra/services/ai/backend_ai_service.dart';
import 'package:vyra/services/backend/realtime_events.dart';
import 'package:vyra/services/voice/tts_service.dart';

void main() {
  group('AnimeSprites', () {
    test('every emotion has decodable idle/talk/blink frames', () {
      for (final emotion in AvatarEmotion.values) {
        expect(AnimeSprites.hasEmotion(emotion.name), isTrue,
            reason: 'missing sprite set for ${emotion.name}');
        for (final state in AnimeSprites.states) {
          final bytes = AnimeSprites.bytesFor(emotion.name, state);
          expect(bytes.length, greaterThan(5000),
              reason: '${emotion.name}/$state suspiciously small');
          // WebP container magic: RIFF....WEBP
          expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
          expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
        }
      }
    });

    test('unknown emotion/state fall back instead of crashing', () {
      expect(AnimeSprites.bytesFor('banana', 'idle').length, greaterThan(0));
      expect(
          AnimeSprites.bytesFor('happy', 'moonwalk').length, greaterThan(0));
    });

    test('gesture poses decode, with talk fallback', () {
      for (final g in ['wave', 'laugh', 'stretch', 'lean']) {
        expect(AnimeSprites.hasGesture(g), isTrue);
        final idle = AnimeSprites.gestureBytesFor(g)!;
        expect(idle.length, greaterThan(5000));
        expect(String.fromCharCodes(idle.sublist(8, 12)), 'WEBP');
        // talking falls back to idle when no dedicated talk frame exists
        expect(AnimeSprites.gestureBytesFor(g, talking: true), isNotNull);
      }
      expect(AnimeSprites.hasGesture('backflip'), isFalse);
      expect(AnimeSprites.gestureBytesFor('backflip'), isNull);
    });
  });

  group('TtsService.pickFemale', () {
    test('prefers explicit female markers', () {
      final pick = TtsService.pickFemale([
        {'name': 'en-us-x-abc-male', 'locale': 'en-US'},
        {'name': 'English Female Warm', 'locale': 'en-GB'},
      ]);
      expect(pick!['name'], 'English Female Warm');
    });

    test('falls back to known female voice codes', () {
      final pick = TtsService.pickFemale([
        {'name': 'en-us-x-iom-local', 'locale': 'en-US'},
        {'name': 'en-us-x-tpa-network', 'locale': 'en-US'},
      ]);
      expect(pick!['name'], 'en-us-x-tpa-network');
    });

    test('returns null when nothing matches', () {
      expect(
        TtsService.pickFemale([
          {'name': 'mystery-voice-1', 'locale': 'en-US'}
        ]),
        isNull,
      );
    });
  });

  group('AvatarEmotion.angry', () {
    test('parses from tag and has a face', () {
      expect(AvatarEmotion.fromTag('angry'), AvatarEmotion.angry);
      expect(AvatarEmotion.fromTag('ANGRY'), AvatarEmotion.angry);
      final face = FaceParams.forEmotion('angry');
      expect(face.browTilt, lessThan(0)); // furrowed, not worried
      expect(face.mouthCurve, lessThan(0)); // downturned
    });

    test('unknown tags still fall back to neutral (old-history safety)', () {
      expect(AvatarEmotion.fromTag('furious'), AvatarEmotion.neutral);
    });
  });

  group('RealtimeEvent.decode', () {
    test('decodes the server event vocabulary', () {
      final ready = RealtimeEvent.decode(jsonEncode({
        'type': 'session.ready',
        'provider': 'ollama',
        'model': 'llama3.1',
        'stt': 'server',
        'tts': 'server',
        'vision_frames': true,
        'vision_frame_interval': 15,
      }));
      expect(ready, isA<SessionReady>());
      expect((ready as SessionReady).serverStt, isTrue);
      expect(ready.serverTts, isTrue);
      expect(ready.visionFrames, isTrue);
      expect(ready.frameIntervalSeconds, 15.0);
      expect(ready.provider, 'ollama');

      // Old servers omit the new fields — safe defaults.
      final oldReady = RealtimeEvent.decode(jsonEncode({
        'type': 'session.ready',
        'provider': 'ollama',
        'model': 'llama3.1',
        'stt': 'client',
      }));
      expect((oldReady as SessionReady).serverTts, isFalse);
      expect(oldReady.visionFrames, isFalse);

      final state = RealtimeEvent.decode(
          jsonEncode({'type': 'state', 'value': 'thinking'}));
      expect((state as StateChanged).phase, CompanionPhase.thinking);

      final say = RealtimeEvent.decode(jsonEncode({
        'type': 'assistant.say',
        'id': 3,
        'text': 'Hey you!',
        'emotion': 'happy',
        'proactive': true,
        'gesture': 'wave',
      }));
      expect(say, isA<AssistantSay>());
      expect((say as AssistantSay).proactive, isTrue);
      expect(say.emotion, 'happy');
      expect(say.gesture, 'wave');

      // gesture is optional — old servers omit it
      final plainSay = RealtimeEvent.decode(jsonEncode({
        'type': 'assistant.say',
        'id': 4,
        'text': 'Hi',
        'emotion': 'neutral',
        'proactive': false,
      }));
      expect((plainSay as AssistantSay).gesture, '');

      expect(
        RealtimeEvent.decode(
            jsonEncode({'type': 'tts.interrupt', 'id': 3})),
        isA<TtsInterrupt>(),
      );
      expect(
        RealtimeEvent.decode(jsonEncode({'type': 'user.final', 'text': 'hi'})),
        isA<UserFinal>(),
      );
      expect(RealtimeEvent.decode(jsonEncode({'type': 'pong'})), isA<Pong>());

      // Her neural voice arriving as MP3 bytes…
      final mp3 = base64Encode([0x49, 0x44, 0x33, 1, 2, 3]);
      final audio = RealtimeEvent.decode(jsonEncode(
          {'type': 'assistant.audio', 'id': 7, 'audio_b64': mp3}));
      expect(audio, isA<AssistantAudio>());
      expect((audio as AssistantAudio).id, 7);
      expect(audio.audio!.length, 6);

      // …and the explicit fall-back-to-device signal.
      final fallback = RealtimeEvent.decode(jsonEncode(
          {'type': 'assistant.audio', 'id': 8, 'audio_b64': ''}));
      expect((fallback as AssistantAudio).audio, isNull);
    });

    test('unknown events and junk are ignored, not crashes', () {
      expect(
        RealtimeEvent.decode(jsonEncode({'type': 'totally.new.thing'})),
        isNull,
      );
      expect(RealtimeEvent.decode('not json at all'), isNull);
      expect(RealtimeEvent.decode('[1,2,3]'), isNull);
    });

    test('client events serialize the wire contract', () {
      final start = jsonDecode(ClientEvents.sessionStart(
        userName: 'Chirag',
        greet: true,
        clientStt: false,
      )) as Map;
      expect(start['type'], 'session.start');
      expect(start['user_name'], 'Chirag');
      expect(start['sample_rate'], 16000);

      final vision = jsonDecode(
          ClientEvents.visionState(present: true, smiling: false)) as Map;
      expect(vision['type'], 'vision.state');
      expect(vision['present'], isTrue);

      final tts = jsonDecode(ClientEvents.ttsState(playing: true)) as Map;
      expect(tts, {'type': 'tts.state', 'playing': true});

      final frame = jsonDecode(ClientEvents.visionFrame(
          Uint8List.fromList([0xFF, 0xD8, 1, 2]))) as Map;
      expect(frame['type'], 'vision.frame');
      expect(base64Decode(frame['jpeg_b64'] as String).length, 4);
    });
  });

  group('BackendAiService', () {
    BackendAiService service({required http.Client client}) =>
        BackendAiService(
          client: client,
          baseUrl: 'http://backend.test:8000',
          apiKey: 'sekret',
        );

    test('sends windowed history + key header, parses clean reply', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'text': 'That is wonderful news!',
            'emotion': 'excited',
            'provider': 'ollama',
            'model': 'llama3.1',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ai = service(client: client);
      ai.seedHistory([
        (isUser: true, text: 'hello'),
        (isUser: false, text: 'hey there!'),
      ]);
      final reply = await ai.send('I got the job!');

      expect(reply.isError, isFalse);
      expect(reply.text, 'That is wonderful news!');
      expect(reply.emotion, 'excited');

      expect(captured.url.path, '/chat');
      expect(captured.headers['X-Vyra-Key'], 'sekret');
      final body = jsonDecode(captured.body) as Map;
      final messages = (body['messages'] as List).cast<Map>();
      expect(messages.length, 3); // seeded 2 + new user turn
      expect(messages.last['role'], 'user');
      expect(messages.last['content'], 'I got the job!');
      expect(messages.first['role'], 'user');
      expect(messages[1]['role'], 'assistant');
    });

    test('server failure returns friendly error and rolls back history',
        () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response('{"detail":"boom"}', 502);
        }
        final body = jsonDecode(request.body) as Map;
        return http.Response(
          jsonEncode({
            'text': 'Recovered! You said: '
                '${(body['messages'] as List).length} msgs',
            'emotion': 'happy',
            'provider': 'echo',
            'model': 'echo-1',
          }),
          200,
        );
      });

      final ai = service(client: client);
      final failed = await ai.send('are you there?');
      expect(failed.isError, isTrue);
      expect(failed.emotion, 'sad');

      // The failed user turn was rolled back → retry sends exactly 1 message.
      final retry = await ai.send('are you there?');
      expect(retry.isError, isFalse);
      expect(retry.text, contains('1 msgs'));
    });

    test('unconfigured service degrades gracefully', () async {
      final ai = BackendAiService(
        client: MockClient((_) async => http.Response('x', 500)),
        baseUrl: '',
      );
      expect(ai.isConfigured, isFalse);
      final reply = await ai.send('hi');
      expect(reply.isError, isTrue);
      expect(reply.text, contains('VYRA_BACKEND_URL'));
    });
  });
}

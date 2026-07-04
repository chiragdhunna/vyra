// Registry for Vyra's embedded anime avatar sprites.
//
// 9 emotions x 3 states (idle / talk / blink), generated from a single
// consistent character reference. Frames are base64 WebP decoded once
// and cached by [AnimeSprites.bytesFor].
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'anime_sprites/neutral_sprites.dart';
import 'anime_sprites/happy_sprites.dart';
import 'anime_sprites/excited_sprites.dart';
import 'anime_sprites/thinking_sprites.dart';
import 'anime_sprites/sad_sprites.dart';
import 'anime_sprites/surprised_sprites.dart';
import 'anime_sprites/caring_sprites.dart';
import 'anime_sprites/cry_sprites.dart';
import 'anime_sprites/angry_sprites.dart';
import 'anime_sprites/gesture_sprites.dart';

class AnimeSprites {
  AnimeSprites._();

  /// The sprites' flat background color — the immersive screen paints this
  /// exact color so the frames blend seamlessly and only SHE is visible.
  static const Color background = Color(0xFF120D24);

  static const List<String> states = ['idle', 'talk', 'blink'];

  /// Gesture poses: overlays that temporarily replace the emotion frame.
  static const Map<String, Map<String, String>> _gestures = {
    'wave': {'idle': kSpriteWaveIdle, 'talk': kSpriteWaveTalk},
    'laugh': {'idle': kSpriteLaughIdle},
    'stretch': {'idle': kSpriteStretchIdle},
    'lean': {'idle': kSpriteLeanIdle},
  };

  static bool hasGesture(String name) => _gestures.containsKey(name);

  /// Frame bytes for a gesture pose; talking falls back to the idle frame
  /// when the gesture has no dedicated talk variant.
  static Uint8List? gestureBytesFor(String name, {bool talking = false}) {
    final sprites = _gestures[name];
    if (sprites == null) return null;
    final b64 = (talking ? sprites['talk'] : null) ?? sprites['idle']!;
    return _cache.putIfAbsent(
        'gesture/$name/${talking && sprites.containsKey('talk') ? 'talk' : 'idle'}',
        () => base64Decode(b64));
  }

  static const Map<String, Map<String, String>> _byEmotion = {
    'neutral': {'idle': kSpriteNeutralIdle, 'talk': kSpriteNeutralTalk, 'blink': kSpriteNeutralBlink},
    'happy': {'idle': kSpriteHappyIdle, 'talk': kSpriteHappyTalk, 'blink': kSpriteHappyBlink},
    'excited': {'idle': kSpriteExcitedIdle, 'talk': kSpriteExcitedTalk, 'blink': kSpriteExcitedBlink},
    'thinking': {'idle': kSpriteThinkingIdle, 'talk': kSpriteThinkingTalk, 'blink': kSpriteThinkingBlink},
    'sad': {'idle': kSpriteSadIdle, 'talk': kSpriteSadTalk, 'blink': kSpriteSadBlink},
    'surprised': {'idle': kSpriteSurprisedIdle, 'talk': kSpriteSurprisedTalk, 'blink': kSpriteSurprisedBlink},
    'caring': {'idle': kSpriteCaringIdle, 'talk': kSpriteCaringTalk, 'blink': kSpriteCaringBlink},
    'cry': {'idle': kSpriteCryIdle, 'talk': kSpriteCryTalk, 'blink': kSpriteCryBlink},
    'angry': {'idle': kSpriteAngryIdle, 'talk': kSpriteAngryTalk, 'blink': kSpriteAngryBlink},
  };

  static final Map<String, Uint8List> _cache = {};

  static bool hasEmotion(String emotion) => _byEmotion.containsKey(emotion);

  /// Decoded frame bytes for [emotion]/[state], with graceful fallbacks:
  /// unknown state -> idle; unknown emotion -> neutral.
  static Uint8List bytesFor(String emotion, String state) {
    final sprites = _byEmotion[emotion] ?? _byEmotion['neutral']!;
    final b64 = sprites[state] ?? sprites['idle']!;
    return _cache.putIfAbsent('$emotion/$state', () => base64Decode(b64));
  }

  /// Pre-decodes every frame (call once, off the first frame's hot path).
  static void warmUp() {
    for (final emotion in _byEmotion.keys) {
      for (final state in states) {
        bytesFor(emotion, state);
      }
    }
    for (final gesture in _gestures.keys) {
      gestureBytesFor(gesture);
      gestureBytesFor(gesture, talking: true);
    }
  }
}

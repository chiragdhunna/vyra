// Registry for Vyra's embedded anime avatar sprites.
//
// 9 emotions x 3 states (idle / talk / blink), generated from a single
// consistent character reference. Frames are base64 WebP decoded once
// and cached by [AnimeSprites.bytesFor].
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'anime_sprites/neutral_sprites.dart';
import 'anime_sprites/happy_sprites.dart';
import 'anime_sprites/excited_sprites.dart';
import 'anime_sprites/thinking_sprites.dart';
import 'anime_sprites/sad_sprites.dart';
import 'anime_sprites/surprised_sprites.dart';
import 'anime_sprites/caring_sprites.dart';
import 'anime_sprites/cry_sprites.dart';
import 'anime_sprites/angry_sprites.dart';

class AnimeSprites {
  AnimeSprites._();

  static const List<String> states = ['idle', 'talk', 'blink'];

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
  }
}

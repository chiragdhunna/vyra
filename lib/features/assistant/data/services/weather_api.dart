import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/permission_service.dart';
import '../models/weather.dart';

/// Friendly, user-facing error for the weather feature.
class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);
  @override
  String toString() => message;
}

/// Fetches current weather from OpenWeatherMap for the device's location.
class WeatherApi {
  WeatherApi._();
  static final WeatherApi instance = WeatherApi._();

  Future<Weather> fetchForCurrentLocation() async {
    // Resolve the location FIRST so the permission prompt always surfaces when
    // the weather feature loads — even if the API key is missing. Previously
    // the key check returned early and the prompt was never reached.
    final pos = await _resolvePosition();
    if (!Env.hasWeatherKey) {
      throw const WeatherException(
        'Add OPENWEATHER_API_KEY to your .env to see live weather.',
      );
    }
    final uri = Uri.parse(
      '${ApiConstants.openWeatherBase}'
      '?lat=${pos.latitude}&lon=${pos.longitude}'
      '&units=metric&appid=${Env.openWeatherApiKey}',
    );

    final http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const WeatherException(
        'Weather request timed out. Check your connection and retry.',
      );
    } on Exception {
      throw const WeatherException(
        "Couldn't reach the weather service. Please retry in a moment.",
      );
    }
    if (res.statusCode != 200) {
      throw WeatherException('Weather service error (${res.statusCode}).');
    }
    return Weather.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Position> _resolvePosition() async {
    // 1) Ask for location permission FIRST, serialized through PermissionService
    // so it never races the microphone request. Two permission dialogs firing
    // at once (both features build eagerly at startup) dropped one prompt and
    // left this Future unresolved — which is why weather hung on "loading"
    // until the app was restarted (issue #10).
    final status =
        await PermissionService.instance.request(Permission.location);
    if (status.isPermanentlyDenied) {
      throw const WeatherException(
        'Location is blocked for Vyra. Enable it in system Settings, then retry.',
      );
    }
    if (!status.isGranted) {
      throw const WeatherException(
        'Location permission is needed for weather.',
      );
    }

    // 2) A cached fix returns instantly and survives a cold GPS — this is the
    // very reason weather only appeared after a restart, so prefer it for
    // city‑level weather.
    final cached = await Geolocator.getLastKnownPosition();
    if (cached != null) return cached;

    // 3) Otherwise get a fresh, time‑bounded fix so the Future can never hang
    // the loading state. Location services must be on for a fresh read.
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const WeatherException(
        'Turn on location services for live weather.',
      );
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on TimeoutException {
      throw const WeatherException(
        "Couldn't get a location fix in time. Make sure GPS is on, then retry.",
      );
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/api_constants.dart';
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
    // 1) Ask for location permission FIRST — before the GPS-services check and
    // (in the caller) before the API-key check — so the system dialog always
    // appears when the weather feature loads, the same way the mic prompt
    // appears when the voice feature initializes. The permission is declared
    // in the manifest; this surfaces the runtime consent. Requesting it ahead
    // of the other gates is what fixes "the prompt is never asked" (issue #10).
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }
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

    // 2) Location services (GPS) must be on for a fresh fix.
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const WeatherException(
        'Turn on location services for live weather.',
      );
    }
    // Without a bound, getCurrentPosition can hang forever when the device
    // never gets a fix (common on emulators and indoors) — the root cause of
    // the weather card spinning endlessly (issue #10). Cap it with a timeLimit
    // and fall back to the last known position so this future always resolves.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw const WeatherException(
        "Couldn't pin down your location in time. "
        'Make sure GPS is on, then tap retry.',
      );
    }
  }
}

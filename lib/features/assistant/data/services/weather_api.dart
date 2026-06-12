import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
    if (!Env.hasWeatherKey) {
      throw const WeatherException(
        'Add OPENWEATHER_API_KEY to your .env to see live weather.',
      );
    }
    final pos = await _resolvePosition();
    final uri = Uri.parse(
      '${ApiConstants.openWeatherBase}'
      '?lat=${pos.latitude}&lon=${pos.longitude}'
      '&units=metric&appid=${Env.openWeatherApiKey}',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw WeatherException('Weather service error (${res.statusCode}).');
    }
    return Weather.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Position> _resolvePosition() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw const WeatherException('Turn on location services for weather.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const WeatherException('Location permission is needed for weather.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }
}

/// Current weather snapshot parsed from the OpenWeatherMap API.
class Weather {
  final String city;
  final double tempC;
  final double feelsLikeC;
  final String description;
  final String main; // e.g. Clear, Clouds, Rain, Snow
  final int humidity;
  final double windSpeed;

  const Weather({
    required this.city,
    required this.tempC,
    required this.feelsLikeC,
    required this.description,
    required this.main,
    required this.humidity,
    required this.windSpeed,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    final weatherList = json['weather'] as List?;
    final first = (weatherList != null && weatherList.isNotEmpty)
        ? weatherList.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final mainBlock = json['main'] as Map<String, dynamic>? ?? const {};
    final wind = json['wind'] as Map<String, dynamic>? ?? const {};

    return Weather(
      city: (json['name'] as String?) ?? 'Your location',
      tempC: (mainBlock['temp'] as num?)?.toDouble() ?? 0,
      feelsLikeC: (mainBlock['feels_like'] as num?)?.toDouble() ?? 0,
      description: (first['description'] as String?) ?? '',
      main: (first['main'] as String?) ?? '',
      humidity: (mainBlock['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0,
    );
  }

  int get tempRounded => tempC.round();
  int get feelsLikeRounded => feelsLikeC.round();
}

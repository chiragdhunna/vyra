import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/models/weather.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key, required this.weather, required this.onRefresh});

  final AsyncValue<Weather> weather;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accentDeep, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: weather.when(
        loading: () => const SizedBox(
          height: 90,
          child: Center(
              child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (e, _) => _Message(
          icon: Icons.cloud_off_rounded,
          text: e.toString(),
          onRetry: onRefresh,
        ),
        data: (w) => _WeatherBody(weather: w, onRefresh: onRefresh),
      ),
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.weather, required this.onRefresh});

  final Weather weather;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_iconFor(weather.main), color: Colors.white, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Text(weather.city,
                  style: AppTextStyles.title.copyWith(color: Colors.white)),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('${weather.tempRounded}°',
            style: AppTextStyles.display.copyWith(
              color: Colors.white,
              fontSize: 56,
            )),
        Text(
          '${weather.description.capitalize} • feels like ${weather.feelsLikeRounded}°',
          style: AppTextStyles.bodyMuted.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Chip(icon: Icons.water_drop_rounded, label: '${weather.humidity}%'),
            const SizedBox(width: 10),
            _Chip(
                icon: Icons.air_rounded,
                label: '${weather.windSpeed.round()} m/s'),
          ],
        ),
      ],
    );
  }

  IconData _iconFor(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny_rounded;
      case 'clouds':
        return Icons.cloud_rounded;
      case 'rain':
      case 'drizzle':
        return Icons.grain_rounded;
      case 'thunderstorm':
        return Icons.flash_on_rounded;
      case 'snow':
        return Icons.ac_unit_rounded;
      case 'mist':
      case 'fog':
      case 'haze':
      case 'smoke':
        return Icons.blur_on_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.label.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(text, style: AppTextStyles.bodyMuted.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

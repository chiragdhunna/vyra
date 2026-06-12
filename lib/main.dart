import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/flavor_config.dart';
import 'core/utils/app_logger.dart';
import 'services/notifications/notification_service.dart';
import 'services/storage/storage_service.dart';

/// Build environments. Each entrypoint (main_dev/main_staging/main_prod) calls
/// [mainCommon] with the matching value.
enum Environment { dev, prod, staging }

Future<void> mainCommon(Environment env) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlavorConfig.init(switch (env) {
    Environment.dev => Flavor.dev,
    Environment.staging => Flavor.staging,
    Environment.prod => Flavor.prod,
  });

  // Load .env. Safe if the file is missing — features degrade gracefully
  // (e.g. chat shows a friendly "add your Gemini key" message).
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    AppLogger.w('No .env file loaded ($e). Features needing keys will be limited.');
  }

  // Core services.
  await StorageService.instance.init();
  await NotificationService.instance.init();

  // Firebase is entirely optional — only initialize when fully configured.
  if (Env.hasFirebase) {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: Env.firebaseApiKey,
          appId: Env.firebaseAppId,
          messagingSenderId: Env.firebaseMessagingSenderId,
          projectId: Env.firebaseProjectId,
          storageBucket: Env.firebaseStorageBucket.isEmpty
              ? null
              : Env.firebaseStorageBucket,
        ),
      );
      AppLogger.d('Firebase initialized');
    } catch (e) {
      AppLogger.w('Firebase init skipped: $e');
    }
  }

  runApp(const ProviderScope(child: VyraApp()));
}

void main() => mainCommon(Environment.dev);

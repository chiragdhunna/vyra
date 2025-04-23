import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment { dev, prod, staging }

void mainCommon(Environment env) async {
  // Pass env to your app, use it for config, etc.

  await dotenv.load(); // Load the .env file

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      appId: dotenv.env['FIREBASE_APP_ID']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'],
    ),
  );

  runApp(MyApp(env: env));
}

class MyApp extends StatelessWidget {
  final Environment env;
  const MyApp({required this.env, super.key});

  @override
  Widget build(BuildContext context) {
    String title;
    switch (env) {
      case Environment.prod:
        title = 'Vyra (Prod)';
        break;
      case Environment.staging:
        title = 'Vyra (Staging)';
        break;
      default:
        title = 'Vyra (Dev)';
    }
    return MaterialApp(
      title: title,
      home: Scaffold(
        appBar: AppBar(title: Text('Vyra - ${env.name}')),
        body: Center(child: Text('Running in ${env.name} mode')),
      ),
    );
  }
}

void main() {
  mainCommon(Environment.dev);
}

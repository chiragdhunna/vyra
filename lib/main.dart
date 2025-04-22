import 'package:flutter/material.dart';

enum Environment { dev, prod, staging }

void mainCommon(Environment env) {
  // Pass env to your app, use it for config, etc.
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

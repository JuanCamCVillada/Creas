import 'package:flutter/material.dart';

import 'engine/graph_generator.dart';
import 'storage/api_key_store.dart';
import 'storage/session_store.dart';

class CreativeApp extends StatelessWidget {
  const CreativeApp({
    super.key,
    required this.sessionStore,
    required this.apiKeyStore,
    required this.generator,
  });

  final SessionStore sessionStore;
  final ApiKeyStore apiKeyStore;
  final GraphGenerator generator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Genealogía Creativa',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const Scaffold(
        body: Center(child: Text('Genealogía Creativa')),
      ),
    );
  }
}

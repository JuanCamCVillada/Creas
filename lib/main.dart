import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'engine/gemini_client.dart';
import 'engine/generation_engine.dart';
import 'engine/llm_provider.dart';
import 'engine/openai_client.dart';
import 'storage/api_key_store.dart';
import 'storage/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  const apiKeyStore = SecureApiKeyStore();

  runApp(CreativeApp(
    sessionStore: LocalSessionStore(prefs),
    apiKeyStore: apiKeyStore,
    generator: GenerationEngine(
      clients: {
        // In debug builds, print each request's token usage so what a
        // generation really costs can be read off instead of estimated.
        LlmProvider.gemini: GeminiClient(onUsage: kDebugMode ? debugPrint : null),
        LlmProvider.openai: OpenAiClient(onUsage: kDebugMode ? debugPrint : null),
      },
      apiKeyStore: apiKeyStore,
    ),
  ));
}

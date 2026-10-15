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
        LlmProvider.gemini: GeminiClient(),
        LlmProvider.openai: OpenAiClient(),
      },
      apiKeyStore: apiKeyStore,
    ),
  ));
}

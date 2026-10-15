import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../engine/llm_provider.dart';

abstract class ApiKeyStore {
  Future<String?> getApiKey();
  Future<void> setApiKey(String key);
  Future<void> clearApiKey();

  /// The provider the user chose by hand in settings, or null when they left
  /// it on automatic — in which case it's detected from the key itself.
  Future<LlmProvider?> getProvider();

  /// Pass null to go back to automatic detection.
  Future<void> setProvider(LlmProvider? provider);
}

class SecureApiKeyStore implements ApiKeyStore {
  const SecureApiKeyStore({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;
  // Kept as-is: renaming would orphan keys users already saved.
  static const _key = 'gemini_api_key';
  static const _providerKey = 'llm_provider';

  @override
  Future<String?> getApiKey() => storage.read(key: _key);

  @override
  Future<void> setApiKey(String key) => storage.write(key: _key, value: key);

  @override
  Future<void> clearApiKey() async {
    await storage.delete(key: _key);
    await storage.delete(key: _providerKey);
  }

  @override
  Future<LlmProvider?> getProvider() async {
    final name = await storage.read(key: _providerKey);
    for (final provider in LlmProvider.values) {
      if (provider.name == name) return provider;
    }
    return null;
  }

  @override
  Future<void> setProvider(LlmProvider? provider) => provider == null
      ? storage.delete(key: _providerKey)
      : storage.write(key: _providerKey, value: provider.name);
}

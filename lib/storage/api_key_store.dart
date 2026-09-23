import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ApiKeyStore {
  Future<String?> getApiKey();
  Future<void> setApiKey(String key);
  Future<void> clearApiKey();
}

class SecureApiKeyStore implements ApiKeyStore {
  const SecureApiKeyStore({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;
  static const _key = 'gemini_api_key';

  @override
  Future<String?> getApiKey() => storage.read(key: _key);

  @override
  Future<void> setApiKey(String key) => storage.write(key: _key, value: key);

  @override
  Future<void> clearApiKey() => storage.delete(key: _key);
}

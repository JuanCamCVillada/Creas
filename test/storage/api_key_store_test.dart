import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:creative/engine/llm_provider.dart';
import 'package:creative/storage/api_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform({});
  });

  group('SecureApiKeyStore', () {
    test('getApiKey returns null when nothing is stored', () async {
      const store = SecureApiKeyStore();
      expect(await store.getApiKey(), isNull);
    });

    test('setApiKey then getApiKey returns the stored key', () async {
      const store = SecureApiKeyStore();
      await store.setApiKey('AIzaTest');
      expect(await store.getApiKey(), 'AIzaTest');
    });

    test('clearApiKey removes the stored key', () async {
      const store = SecureApiKeyStore();
      await store.setApiKey('AIzaTest');
      await store.clearApiKey();
      expect(await store.getApiKey(), isNull);
    });

    test('getProvider is null until one is chosen — automatic detection', () async {
      const store = SecureApiKeyStore();
      expect(await store.getProvider(), isNull);
    });

    test('setProvider then getProvider round-trips each provider', () async {
      const store = SecureApiKeyStore();
      for (final provider in LlmProvider.values) {
        await store.setProvider(provider);
        expect(await store.getProvider(), provider);
      }
    });

    test('setProvider(null) goes back to automatic', () async {
      const store = SecureApiKeyStore();
      await store.setProvider(LlmProvider.openai);
      await store.setProvider(null);
      expect(await store.getProvider(), isNull);
    });

    test('clearApiKey also forgets the pinned provider, so a stale choice '
        'cannot outlive the key it was made for', () async {
      const store = SecureApiKeyStore();
      await store.setApiKey('sk-abc');
      await store.setProvider(LlmProvider.openai);
      await store.clearApiKey();
      expect(await store.getProvider(), isNull);
    });
  });
}

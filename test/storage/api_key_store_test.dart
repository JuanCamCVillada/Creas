import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    const store = SecureApiKeyStore();

    test('getKey returns null when nothing is stored', () async {
      for (final provider in LlmProvider.values) {
        expect(await store.getKey(provider), isNull);
      }
    });

    test('each provider keeps its own key', () async {
      await store.setKey(LlmProvider.gemini, 'AIzaGemini');
      await store.setKey(LlmProvider.openai, 'sk-proj-openai');

      expect(await store.getKey(LlmProvider.gemini), 'AIzaGemini');
      expect(await store.getKey(LlmProvider.openai), 'sk-proj-openai');
    });

    test('setKey replaces only that provider\'s key', () async {
      await store.setKey(LlmProvider.gemini, 'AIzaOld');
      await store.setKey(LlmProvider.openai, 'sk-keep');
      await store.setKey(LlmProvider.gemini, 'AIzaNew');

      expect(await store.getKey(LlmProvider.gemini), 'AIzaNew');
      expect(await store.getKey(LlmProvider.openai), 'sk-keep');
    });

    test('removeKey removes only that provider\'s key', () async {
      await store.setKey(LlmProvider.gemini, 'AIzaGemini');
      await store.setKey(LlmProvider.openai, 'sk-openai');
      await store.removeKey(LlmProvider.gemini);

      expect(await store.getKey(LlmProvider.gemini), isNull);
      expect(await store.getKey(LlmProvider.openai), 'sk-openai');
    });

    test('getPrimary is null until one is chosen', () async {
      expect(await store.getPrimary(), isNull);
    });

    test('setPrimary round-trips each provider, and null clears it', () async {
      for (final provider in LlmProvider.values) {
        await store.setPrimary(provider);
        expect(await store.getPrimary(), provider);
      }
      await store.setPrimary(null);
      expect(await store.getPrimary(), isNull);
    });

    test('removing the primary\'s key forgets the primary, so it cannot '
        'point at nothing', () async {
      await store.setKey(LlmProvider.openai, 'sk-openai');
      await store.setPrimary(LlmProvider.openai);
      await store.removeKey(LlmProvider.openai);

      expect(await store.getPrimary(), isNull);
    });

    test('removing another provider\'s key leaves the primary alone', () async {
      await store.setKey(LlmProvider.gemini, 'AIzaGemini');
      await store.setKey(LlmProvider.openai, 'sk-openai');
      await store.setPrimary(LlmProvider.openai);
      await store.removeKey(LlmProvider.gemini);

      expect(await store.getPrimary(), LlmProvider.openai);
    });
  });

  group('credentialsInOrder', () {
    const store = SecureApiKeyStore();

    test('is empty with no keys', () async {
      expect(await store.credentialsInOrder(), isEmpty);
    });

    test('lists only providers that have a key, Gemini first by default', () async {
      await store.setKey(LlmProvider.openai, 'sk-openai');
      await store.setKey(LlmProvider.gemini, 'AIzaGemini');

      final order = await store.credentialsInOrder();

      expect(order.map((c) => c.provider), [LlmProvider.gemini, LlmProvider.openai]);
      expect(order.map((c) => c.key), ['AIzaGemini', 'sk-openai']);
    });

    test('puts the primary first', () async {
      await store.setKey(LlmProvider.gemini, 'AIzaGemini');
      await store.setKey(LlmProvider.openai, 'sk-openai');
      await store.setPrimary(LlmProvider.openai);

      final order = await store.credentialsInOrder();

      expect(order.map((c) => c.provider), [LlmProvider.openai, LlmProvider.gemini]);
    });

    test('ignores a primary that has no key', () async {
      await store.setKey(LlmProvider.gemini, 'AIzaGemini');
      await store.setPrimary(LlmProvider.openai);

      final order = await store.credentialsInOrder();

      expect(order.map((c) => c.provider), [LlmProvider.gemini]);
    });
  });

  group('migrating a key saved by an earlier version', () {
    const store = SecureApiKeyStore();
    const raw = FlutterSecureStorage();

    test('a legacy Gemini key moves into the Gemini slot', () async {
      await raw.write(key: 'gemini_api_key', value: 'AIzaLegacy');

      expect(await store.getKey(LlmProvider.gemini), 'AIzaLegacy');
      expect(await store.getKey(LlmProvider.openai), isNull);
    });

    test('a legacy key whose shape says OpenAI moves into the OpenAI slot',
        () async {
      await raw.write(key: 'gemini_api_key', value: 'sk-proj-legacy');

      expect(await store.getKey(LlmProvider.openai), 'sk-proj-legacy');
      expect(await store.getKey(LlmProvider.gemini), isNull);
    });

    test('a legacy provider override wins over the key\'s shape', () async {
      await raw.write(key: 'gemini_api_key', value: 'sk-looks-openai');
      await raw.write(key: 'llm_provider', value: 'gemini');

      expect(await store.getKey(LlmProvider.gemini), 'sk-looks-openai');
      expect(await store.getKey(LlmProvider.openai), isNull);
    });

    test('an unrecognizable legacy key lands on Gemini, the original default',
        () async {
      await raw.write(key: 'gemini_api_key', value: 'mystery-format');

      expect(await store.getKey(LlmProvider.gemini), 'mystery-format');
    });

    test('the old slots are cleared once migrated', () async {
      await raw.write(key: 'gemini_api_key', value: 'AIzaLegacy');
      await raw.write(key: 'llm_provider', value: 'gemini');

      await store.getKey(LlmProvider.gemini);

      expect(await raw.read(key: 'gemini_api_key'), isNull);
      expect(await raw.read(key: 'llm_provider'), isNull);
    });

    test('never overwrites a key already saved in the new layout', () async {
      await store.setKey(LlmProvider.gemini, 'AIzaNew');
      await raw.write(key: 'gemini_api_key', value: 'AIzaStaleLegacy');

      expect(await store.getKey(LlmProvider.gemini), 'AIzaNew');
    });

    test('migrating also happens before a write, so nothing is lost', () async {
      await raw.write(key: 'gemini_api_key', value: 'AIzaLegacy');

      await store.setKey(LlmProvider.openai, 'sk-new');

      expect(await store.getKey(LlmProvider.gemini), 'AIzaLegacy');
      expect(await store.getKey(LlmProvider.openai), 'sk-new');
    });
  });
}

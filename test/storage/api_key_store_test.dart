import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
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
      await store.setApiKey('sk-ant-test');
      expect(await store.getApiKey(), 'sk-ant-test');
    });

    test('clearApiKey removes the stored key', () async {
      const store = SecureApiKeyStore();
      await store.setApiKey('sk-ant-test');
      await store.clearApiKey();
      expect(await store.getApiKey(), isNull);
    });
  });
}

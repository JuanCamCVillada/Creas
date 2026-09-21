import 'package:creative/engine/graph_generation_client.dart';
import 'package:creative/storage/api_key_store.dart';

class FakeApiKeyStore implements ApiKeyStore {
  FakeApiKeyStore([this._key]);

  String? _key;

  @override
  Future<String?> getApiKey() async => _key;

  @override
  Future<void> setApiKey(String key) async => _key = key;

  @override
  Future<void> clearApiKey() async => _key = null;
}

class FakeGraphGenerationClient implements GraphGenerationClient {
  FakeGraphGenerationClient(this._responses);

  final List<Map<String, dynamic> Function()> _responses;
  var _callCount = 0;

  int get callCount => _callCount;

  @override
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  }) async {
    final index = _callCount;
    _callCount++;
    return _responses[index]();
  }
}

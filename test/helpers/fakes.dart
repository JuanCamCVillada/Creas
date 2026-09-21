import 'package:creative/engine/graph_generation_client.dart';
import 'package:creative/engine/graph_generator.dart';
import 'package:creative/models/session.dart';
import 'package:creative/storage/api_key_store.dart';
import 'package:creative/storage/session_store.dart';

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

class FakeGraphGenerator implements GraphGenerator {
  FakeGraphGenerator([this._onGenerate]);

  final Future<GraphSession> Function(String rawInput)? _onGenerate;

  @override
  Future<GraphSession> generate(String rawInput) {
    if (_onGenerate != null) return _onGenerate(rawInput);
    throw UnimplementedError('FakeGraphGenerator has no _onGenerate handler');
  }
}

class FakeSessionStore implements SessionStore {
  FakeSessionStore([List<GraphSession>? initial]) : sessions = initial ?? [];

  final List<GraphSession> sessions;

  @override
  Future<List<GraphSession>> listSessions() async =>
      List.unmodifiable(sessions);

  @override
  Future<void> saveSession(GraphSession session) async {
    sessions.insert(0, session);
  }

  @override
  Future<void> deleteSession(String id) async {
    sessions.removeWhere((s) => s.id == id);
  }
}

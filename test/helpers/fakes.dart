import 'dart:async';

import 'package:creative/engine/api_key_validator.dart';
import 'package:creative/engine/graph_generation_client.dart';
import 'package:creative/engine/graph_generator.dart';
import 'package:creative/engine/llm_provider.dart';
import 'package:creative/models/session.dart';
import 'package:creative/storage/api_key_store.dart';
import 'package:creative/storage/session_store.dart';

class FakeApiKeyStore implements ApiKeyStore {
  FakeApiKeyStore({Map<LlmProvider, String>? keys, LlmProvider? primary})
      : _keys = {...?keys},
        _primary = primary;

  final Map<LlmProvider, String> _keys;
  LlmProvider? _primary;

  @override
  Future<String?> getKey(LlmProvider provider) async => _keys[provider];

  @override
  Future<void> setKey(LlmProvider provider, String key) async => _keys[provider] = key;

  @override
  Future<void> removeKey(LlmProvider provider) async {
    _keys.remove(provider);
    if (_primary == provider) _primary = null;
  }

  @override
  Future<LlmProvider?> getPrimary() async => _primary;

  @override
  Future<void> setPrimary(LlmProvider? provider) async => _primary = provider;
}

/// Answers every validation with [result] and records what it was asked.
class FakeApiKeyValidator implements ApiKeyValidator {
  FakeApiKeyValidator(this.result);

  KeyCheckResult result;

  /// When set, validate() waits for it — lets a test hold the "verifying"
  /// state open instead of racing it.
  Completer<void>? gate;
  String? lastKey;
  LlmProvider? lastProvider;
  int callCount = 0;

  @override
  Future<KeyCheckResult> validate(String key, {LlmProvider? provider}) async {
    callCount++;
    lastKey = key;
    lastProvider = provider;
    await gate?.future;
    return result;
  }
}

class FakeGraphGenerationClient implements GraphGenerationClient {
  FakeGraphGenerationClient(this._responses);

  final List<Map<String, dynamic> Function()> _responses;
  var _callCount = 0;

  /// The key and retry override each call was made with, in order — so a
  /// test can check which provider's key reached which client.
  final List<String> apiKeysSeen = [];
  final List<int?> maxRetriesSeen = [];

  int get callCount => _callCount;

  @override
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
    int? maxRetries,
  }) async {
    apiKeysSeen.add(apiKey);
    maxRetriesSeen.add(maxRetries);
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

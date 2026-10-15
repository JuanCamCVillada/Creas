import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../engine/llm_provider.dart';

/// A key together with the provider it belongs to.
class Credential {
  const Credential(this.provider, this.key);

  final LlmProvider provider;
  final String key;
}

/// One key per provider, so a second provider can take over when the first
/// fails, plus which provider to try first.
abstract class ApiKeyStore {
  Future<String?> getKey(LlmProvider provider);
  Future<void> setKey(LlmProvider provider, String key);
  Future<void> removeKey(LlmProvider provider);

  /// The provider the user wants tried first, or null to leave it to the
  /// default order (see [ApiKeyStoreOrdering.credentialsInOrder]).
  Future<LlmProvider?> getPrimary();

  /// Pass null to go back to the default order.
  Future<void> setPrimary(LlmProvider? provider);
}

extension ApiKeyStoreOrdering on ApiKeyStore {
  /// Every provider that has a key, in the order they should be tried: the
  /// primary first (when it's set and actually has a key), then the rest in
  /// [LlmProvider] order — Gemini before OpenAI, since Gemini has a free tier
  /// and a user who added both most likely wants it spent first.
  Future<List<Credential>> credentialsInOrder() async {
    final configured = <Credential>[];
    for (final provider in LlmProvider.values) {
      final key = await getKey(provider);
      if (key != null && key.isNotEmpty) configured.add(Credential(provider, key));
    }
    final primary = await getPrimary();
    final primaryIndex = configured.indexWhere((c) => c.provider == primary);
    if (primaryIndex > 0) configured.insert(0, configured.removeAt(primaryIndex));
    return configured;
  }
}

class SecureApiKeyStore implements ApiKeyStore {
  const SecureApiKeyStore({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;

  static const _primaryKey = 'primary_provider';

  // The original single-key layout: one slot that held whichever key the
  // user pasted, plus an optional provider override. Only read now, to move
  // a key saved by an earlier version into its provider's slot.
  static const _legacyKey = 'gemini_api_key';
  static const _legacyProviderKey = 'llm_provider';

  static String _slot(LlmProvider provider) => 'api_key_${provider.name}';

  static LlmProvider? _parse(String? name) {
    for (final provider in LlmProvider.values) {
      if (provider.name == name) return provider;
    }
    return null;
  }

  /// Moves a key saved by an earlier version into its provider's slot —
  /// whichever the user had pinned, else whichever its shape says, else
  /// Gemini (the original default). Never overwrites a key already saved in
  /// the new layout, and does nothing once the old slot is gone.
  Future<void> _migrateLegacy() async {
    final legacy = await storage.read(key: _legacyKey);
    if (legacy == null) return;

    final provider = _parse(await storage.read(key: _legacyProviderKey)) ??
        detectProvider(legacy) ??
        LlmProvider.gemini;
    if (legacy.isNotEmpty && await storage.read(key: _slot(provider)) == null) {
      await storage.write(key: _slot(provider), value: legacy);
    }
    await storage.delete(key: _legacyKey);
    await storage.delete(key: _legacyProviderKey);
  }

  @override
  Future<String?> getKey(LlmProvider provider) async {
    await _migrateLegacy();
    return storage.read(key: _slot(provider));
  }

  @override
  Future<void> setKey(LlmProvider provider, String key) async {
    await _migrateLegacy();
    await storage.write(key: _slot(provider), value: key);
  }

  @override
  Future<void> removeKey(LlmProvider provider) async {
    await _migrateLegacy();
    await storage.delete(key: _slot(provider));
    // A primary that no longer has a key would just be ignored; forgetting
    // it keeps the stored state honest.
    if (_parse(await storage.read(key: _primaryKey)) == provider) {
      await storage.delete(key: _primaryKey);
    }
  }

  @override
  Future<LlmProvider?> getPrimary() async => _parse(await storage.read(key: _primaryKey));

  @override
  Future<void> setPrimary(LlmProvider? provider) => provider == null
      ? storage.delete(key: _primaryKey)
      : storage.write(key: _primaryKey, value: provider.name);
}

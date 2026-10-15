/// The LLM providers the app can generate graphs with. Which one runs is
/// decided by the key the user pastes (see [detectProvider]) unless they
/// override it explicitly in settings.
enum LlmProvider { gemini, openai }

extension LlmProviderLabel on LlmProvider {
  String get label => switch (this) {
        LlmProvider.gemini => 'GEMINI',
        LlmProvider.openai => 'OPENAI',
      };
}

/// True for an Anthropic key (`sk-ant-…`). Recognized only so settings can
/// say "not supported" instead of mistaking it for an OpenAI key, whose
/// prefix (`sk-`) it shares.
bool isAnthropicKey(String key) => key.trim().startsWith('sk-ant-');

/// Best guess of the provider from a key's shape, or null when it can't be
/// told (an empty key, an unfamiliar prefix, or an unsupported provider).
///
///  * Gemini / Google AI Studio keys start with `AIza`.
///  * OpenAI keys start with `sk-` (including project keys, `sk-proj-…`).
LlmProvider? detectProvider(String key) {
  final trimmed = key.trim();
  if (trimmed.startsWith('AIza')) return LlmProvider.gemini;
  if (isAnthropicKey(trimmed)) return null;
  if (trimmed.startsWith('sk-')) return LlmProvider.openai;
  return null;
}

/// The provider that should serve a request: an explicit choice made in
/// settings wins, then whatever the key's shape says, then Gemini — the
/// original default, which keeps keys saved before provider selection
/// existed working.
LlmProvider resolveProvider(String key, {LlmProvider? explicit}) =>
    explicit ?? detectProvider(key) ?? LlmProvider.gemini;

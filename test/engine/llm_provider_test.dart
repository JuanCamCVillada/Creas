import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/llm_provider.dart';

void main() {
  group('detectProvider', () {
    test('recognizes a Gemini key by its AIza prefix', () {
      expect(detectProvider('AIzaSyD-example'), LlmProvider.gemini);
    });

    test('recognizes OpenAI keys, classic and project-scoped', () {
      expect(detectProvider('sk-abc123'), LlmProvider.openai);
      expect(detectProvider('sk-proj-abc123'), LlmProvider.openai);
    });

    test('ignores surrounding whitespace, as pasted keys often have', () {
      expect(detectProvider('  sk-abc123\n'), LlmProvider.openai);
      expect(detectProvider('\tAIzaSyD-example '), LlmProvider.gemini);
    });

    test('does not mistake an Anthropic key for an OpenAI one', () {
      // sk-ant-… also starts with sk-, so this is the case that matters.
      expect(detectProvider('sk-ant-api03-abc'), isNull);
      expect(isAnthropicKey('sk-ant-api03-abc'), isTrue);
      expect(isAnthropicKey('sk-proj-abc'), isFalse);
    });

    test('returns null when nothing can be told', () {
      expect(detectProvider(''), isNull);
      expect(detectProvider('   '), isNull);
      expect(detectProvider('hello-world'), isNull);
    });
  });

  group('resolveProvider', () {
    test('an explicit choice wins over what the key looks like', () {
      expect(resolveProvider('sk-abc', explicit: LlmProvider.gemini), LlmProvider.gemini);
    });

    test('otherwise the key decides', () {
      expect(resolveProvider('sk-abc'), LlmProvider.openai);
      expect(resolveProvider('AIzaX'), LlmProvider.gemini);
    });

    test('an unrecognizable key falls back to Gemini, the original default', () {
      expect(resolveProvider('mystery'), LlmProvider.gemini);
      expect(resolveProvider('sk-ant-x'), LlmProvider.gemini);
    });
  });
}

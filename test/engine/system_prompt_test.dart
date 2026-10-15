// test/engine/system_prompt_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/icon_catalog.dart';
import 'package:creative/engine/system_prompt.dart';
import 'package:creative/engine/tool_schema.dart';

void main() {
  group('creativeGraphSystemPrompt', () {
    test('covers the node types, edge relations and turning point rules', () {
      expect(creativeGraphSystemPrompt, contains('Fuente'));
      expect(creativeGraphSystemPrompt, contains('Concepto'));
      expect(creativeGraphSystemPrompt, contains('desencadena'));
      expect(creativeGraphSystemPrompt, contains('deriva_de'));
      expect(creativeGraphSystemPrompt, contains('inspira'));
      expect(creativeGraphSystemPrompt, contains('transforma_en'));
      expect(creativeGraphSystemPrompt, contains('acyclic'));
      expect(creativeGraphSystemPrompt, contains('emit_creative_graph'));
    });

    test('instructs the model to preserve the user\'s own language', () {
      expect(creativeGraphSystemPrompt.toLowerCase(),
          contains('the user\'s language'.toLowerCase()));
    });

    test('instructs the model not to invent turning points or dates', () {
      final lower = creativeGraphSystemPrompt.toLowerCase();
      expect(lower, contains('propose no candidates'));
      expect(lower, contains('never invent dates'));
    });

    test('lists every allowed icon name and tells the model icon is optional', () {
      for (final name in allowedNodeIconNames) {
        expect(creativeGraphSystemPrompt, contains(name));
      }
      expect(creativeGraphSystemPrompt.toLowerCase(), contains('omit icon'));
    });

    test('tells the model to keep its output compact', () {
      // Output tokens cost several times what input tokens do, so these
      // rules are where the per-generation savings come from.
      final lower = creativeGraphSystemPrompt.toLowerCase();
      expect(lower, contains('keep the output compact'));
      expect(lower, contains('one short sentence'));
      expect(lower, contains('never every pair'));
      expect(lower, contains('instead of writing null'));
    });

    test('no longer asks for the timestamp / sequence fields it dropped', () {
      expect(creativeGraphSystemPrompt, isNot(contains('timestamp')));
      expect(creativeGraphSystemPrompt, isNot(contains('sequence')));
    });
  });

  group('static request size', () {
    final staticChars = creativeGraphSystemPrompt.length +
        jsonEncode(emitCreativeGraphToolSchema['input_schema']).length +
        (emitCreativeGraphToolSchema['description'] as String).length;

    test('stays within budget — it is paid for on every single generation', () {
      // ~6.8k chars (~1.7k tokens) today. Raise this on purpose, not by
      // drift: each extra 1k chars is ~250 input tokens on every request.
      expect(staticChars, lessThanOrEqualTo(7500));
    });

    test('stays above the ~1k-token floor where OpenAI and Gemini start '
        'discounting a repeated prompt prefix automatically', () {
      // Shrinking it below this would make repeat generations MORE
      // expensive, not less. ~4 chars per token.
      expect(staticChars, greaterThanOrEqualTo(4200));
    });
  });
}

// test/engine/system_prompt_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/system_prompt.dart';

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
  });
}

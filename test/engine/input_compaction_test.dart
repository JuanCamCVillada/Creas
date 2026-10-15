import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/input_compaction.dart';

void main() {
  group('compactInput', () {
    test('trims trailing spaces on every line', () {
      expect(compactInput('hola   \nmundo\t'), 'hola\nmundo');
    });

    test('collapses runs of blank lines to a single blank line', () {
      expect(compactInput('uno\n\n\n\n\ndos'), 'uno\n\ndos');
    });

    test('treats a line of only spaces as blank', () {
      expect(compactInput('uno\n   \n   \n\ndos'), 'uno\n\ndos');
    });

    test('normalizes Windows and old-Mac line endings', () {
      expect(compactInput('uno\r\ndos\rtres'), 'uno\ndos\ntres');
    });

    test('trims the whole text', () {
      expect(compactInput('\n\n  hola  \n\n'), '  hola');
    });

    test('keeps spaces inside and at the start of a line, so pasted code '
        'keeps its indentation', () {
      const code = 'void main() {\n  if (x) {\n    run();\n  }\n}';
      expect(compactInput(code), code);
    });

    test('keeps a paragraph break the user wrote', () {
      expect(compactInput('uno\n\ndos'), 'uno\n\ndos');
    });

    test('an all-whitespace input becomes empty', () {
      expect(compactInput('  \n\t\n   '), isEmpty);
    });
  });
}

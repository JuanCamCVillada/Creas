// test/engine/tool_schema_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/icon_catalog.dart';
import 'package:creative/engine/tool_schema.dart';

void main() {
  group('emitCreativeGraphToolSchema', () {
    test('has the expected top-level tool shape', () {
      expect(emitCreativeGraphToolSchema['name'], 'emit_creative_graph');
      expect(emitCreativeGraphToolSchema['description'], isNotEmpty);

      final inputSchema =
          emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>;
      expect(inputSchema['type'], 'OBJECT');

      final properties = inputSchema['properties'] as Map<String, dynamic>;
      expect(properties.keys, containsAll([
        'nodes',
        'edges',
        'affinity_edges',
        'turning_point_candidates',
        'followup_questions',
      ]));

      final required = inputSchema['required'] as List;
      expect(required, containsAll([
        'nodes',
        'edges',
        'affinity_edges',
        'turning_point_candidates',
        'followup_questions',
      ]));
    });

    test('node schema enumerates type and origin values', () {
      final inputSchema =
          emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>;
      final properties = inputSchema['properties'] as Map<String, dynamic>;
      final nodeItemSchema =
          (properties['nodes'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final nodeProperties =
          nodeItemSchema['properties'] as Map<String, dynamic>;

      expect((nodeProperties['type'] as Map)['enum'], ['fuente', 'concepto']);
      expect(
          (nodeProperties['origin'] as Map)['enum'], ['usuario', 'sugerido']);

      // Gemini requires format:"enum" alongside any STRING enum, or the
      // schema is rejected by the API.
      expect((nodeProperties['type'] as Map)['format'], 'enum');
      expect((nodeProperties['origin'] as Map)['format'], 'enum');
    });

    test('node schema exposes icon as an optional enum matching the icon catalog', () {
      final inputSchema =
          emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>;
      final properties = inputSchema['properties'] as Map<String, dynamic>;
      final nodeItemSchema =
          (properties['nodes'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final nodeProperties =
          nodeItemSchema['properties'] as Map<String, dynamic>;
      final nodeRequired = nodeItemSchema['required'] as List;

      final iconSchema = nodeProperties['icon'] as Map<String, dynamic>;
      expect(iconSchema['type'], 'STRING');
      expect(iconSchema['format'], 'enum');
      expect(iconSchema['enum'], allowedNodeIconNames);
      expect(nodeRequired, isNot(contains('icon')));
    });

    group('toStandardJsonSchema', () {
      final converted = toStandardJsonSchema(
        emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>,
      );
      final nodeProps = (((converted['properties'] as Map)['nodes'] as Map)['items']
          as Map)['properties'] as Map<String, dynamic>;

      test('lowercases every type name', () {
        expect(converted['type'], 'object');
        expect((converted['properties'] as Map)['nodes']['type'], 'array');
        expect((nodeProps['label'] as Map)['type'], 'string');
        expect((nodeProps['confidence'] as Map)['type'], 'number');
        expect((nodeProps['sequence'] as Map)['type'], 'integer');
      });

      test('drops the Gemini-only format:"enum" marker but keeps the enum', () {
        expect((nodeProps['type'] as Map).containsKey('format'), isFalse);
        expect((nodeProps['type'] as Map)['enum'], ['fuente', 'concepto']);
        expect((nodeProps['icon'] as Map)['enum'], allowedNodeIconNames);
      });

      test('does not mistake a property NAMED type for a type keyword', () {
        // The node schema has a property literally called "type"; it must
        // survive as a property whose own type is lowercased.
        expect(nodeProps.containsKey('type'), isTrue);
        expect((nodeProps['type'] as Map)['type'], 'string');
      });

      test('keeps the required lists untouched', () {
        expect(converted['required'], containsAll(['nodes', 'edges']));
      });

      test('does not mutate the original Gemini-dialect schema', () {
        final original = emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>;
        expect(original['type'], 'OBJECT');
        final originalProps = (((original['properties'] as Map)['nodes'] as Map)['items']
            as Map)['properties'] as Map;
        expect((originalProps['type'] as Map)['format'], 'enum');
      });
    });

    test('edge schema enumerates the four lineage relations', () {
      final inputSchema =
          emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>;
      final properties = inputSchema['properties'] as Map<String, dynamic>;
      final edgeItemSchema =
          (properties['edges'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final edgeProperties =
          edgeItemSchema['properties'] as Map<String, dynamic>;

      expect((edgeProperties['relation'] as Map)['enum'],
          ['desencadena', 'deriva_de', 'inspira', 'transforma_en']);
    });
  });
}

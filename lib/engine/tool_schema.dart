import 'icon_catalog.dart';

/// [emitCreativeGraphToolSchema]'s `input_schema` in standard JSON Schema,
/// for providers that don't use Gemini's dialect (OpenAI): lowercase type
/// names, and no `format: "enum"` — that marker is Gemini-only and a
/// standard enum already says what it means. Derived from the one schema
/// rather than hand-copied, so the two can't drift apart.
Map<String, dynamic> toStandardJsonSchema(Map<String, dynamic> geminiSchema) {
  Object? convert(Object? node) {
    if (node is Map) {
      return {
        for (final entry in node.entries)
          if (!(entry.key == 'format' && entry.value == 'enum'))
            entry.key as String: entry.key == 'type' && entry.value is String
                ? (entry.value as String).toLowerCase()
                : convert(entry.value),
      };
    }
    if (node is List) return [for (final item in node) convert(item)];
    return node;
  }

  return convert(geminiSchema) as Map<String, dynamic>;
}

const Map<String, dynamic> emitCreativeGraphToolSchema = {
  'name': 'emit_creative_graph',
  'description':
      'Emit the creative-provenance graph: Fuente/Concepto nodes, directed '
      'lineage edges, affinity edges, candidate turning points, and '
      'follow-up questions when the input is too thin.',
  // Gemini's function-declaration Schema uses UPPERCASE type names (STRING,
  // OBJECT, ARRAY, NUMBER, INTEGER) and requires format:"enum" alongside any
  // string enum — see https://ai.google.dev/api/generate-content (Schema).
  'input_schema': {
    'type': 'OBJECT',
    'properties': {
      'nodes': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'id': {'type': 'STRING'},
            'type': {
              'type': 'STRING',
              'format': 'enum',
              'enum': ['fuente', 'concepto'],
            },
            'label': {'type': 'STRING'},
            'description': {'type': 'STRING'},
            'cluster': {'type': 'STRING'},
            'origin': {
              'type': 'STRING',
              'format': 'enum',
              'enum': ['usuario', 'sugerido'],
            },
            'confidence': {'type': 'NUMBER'},
            // No timestamp / sequence: nothing in the app reads them, and
            // the model would write both for every node on every request.
            // Node still parses them, so sessions saved earlier load fine.
            'level': {'type': 'INTEGER'},
            'referente_of': {'type': 'STRING'},
            'icon': {
              'type': 'STRING',
              'format': 'enum',
              'enum': allowedNodeIconNames,
            },
          },
          'required': ['id', 'type', 'label', 'description', 'cluster', 'origin'],
        },
      },
      'edges': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'id': {'type': 'STRING'},
            'source': {'type': 'STRING'},
            'target': {'type': 'STRING'},
            'relation': {
              'type': 'STRING',
              'format': 'enum',
              'enum': ['desencadena', 'deriva_de', 'inspira', 'transforma_en'],
            },
          },
          'required': ['id', 'source', 'target', 'relation'],
        },
      },
      'affinity_edges': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'source': {'type': 'STRING'},
            'target': {'type': 'STRING'},
            'weight': {'type': 'NUMBER'},
          },
          'required': ['source', 'target', 'weight'],
        },
      },
      'turning_point_candidates': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'node_id': {'type': 'STRING'},
            'evidence': {'type': 'STRING'},
          },
          'required': ['node_id', 'evidence'],
        },
      },
      'followup_questions': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': [
      'nodes',
      'edges',
      'affinity_edges',
      'turning_point_candidates',
      'followup_questions',
    ],
  },
};

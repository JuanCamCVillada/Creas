import 'icon_catalog.dart';

const Map<String, dynamic> emitCreativeGraphToolSchema = {
  'name': 'emit_creative_graph',
  'description':
      'Emit the extracted creative-provenance graph: Fuente/Concepto nodes, '
      'the directed lineage between them, the undirected affinity edges for '
      'the Jardín Digital view, candidate turning points, and any follow-up '
      'questions needed when the input is too thin to build a lineage.',
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
            'timestamp': {'type': 'STRING'},
            'sequence': {'type': 'INTEGER'},
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

const Map<String, dynamic> emitCreativeGraphToolSchema = {
  'name': 'emit_creative_graph',
  'description':
      'Emit the extracted creative-provenance graph: Fuente/Concepto nodes, '
      'the directed lineage between them, the undirected affinity edges for '
      'the Jardín Digital view, candidate turning points, and any follow-up '
      'questions needed when the input is too thin to build a lineage.',
  'input_schema': {
    'type': 'object',
    'properties': {
      'nodes': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'type': {
              'type': 'string',
              'enum': ['fuente', 'concepto'],
            },
            'label': {'type': 'string'},
            'description': {'type': 'string'},
            'cluster': {'type': 'string'},
            'origin': {
              'type': 'string',
              'enum': ['usuario', 'sugerido'],
            },
            'confidence': {'type': 'number'},
            'timestamp': {'type': 'string'},
            'sequence': {'type': 'integer'},
            'level': {'type': 'integer', 'enum': [1, 2]},
            'referente_of': {'type': 'string'},
          },
          'required': ['id', 'type', 'label', 'description', 'cluster', 'origin'],
        },
      },
      'edges': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'source': {'type': 'string'},
            'target': {'type': 'string'},
            'relation': {
              'type': 'string',
              'enum': ['desencadena', 'deriva_de', 'inspira', 'transforma_en'],
            },
          },
          'required': ['id', 'source', 'target', 'relation'],
        },
      },
      'affinity_edges': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'source': {'type': 'string'},
            'target': {'type': 'string'},
            'weight': {'type': 'number'},
          },
          'required': ['source', 'target', 'weight'],
        },
      },
      'turning_point_candidates': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'node_id': {'type': 'string'},
            'evidence': {'type': 'string'},
          },
          'required': ['node_id', 'evidence'],
        },
      },
      'followup_questions': {
        'type': 'array',
        'items': {'type': 'string'},
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

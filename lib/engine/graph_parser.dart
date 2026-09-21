import '../models/node.dart';
import '../models/lineage_edge.dart';
import '../models/affinity_edge.dart';
import '../models/turning_point.dart';
import '../models/creative_graph.dart';

class GraphParseException implements Exception {
  const GraphParseException(this.message);
  final String message;

  @override
  String toString() => 'GraphParseException: $message';
}

CreativeGraph parseCreativeGraph(Map<String, dynamic> args) {
  try {
    final nodes = _parseList(args['nodes'], 'nodes')
        .asMap()
        .entries
        .map((e) => _wrapItem(e.key, 'nodes', () => Node.fromJson(e.value as Map<String, dynamic>)))
        .toList();

    final edges = _parseList(args['edges'], 'edges')
        .asMap()
        .entries
        .map((e) => _wrapItem(e.key, 'edges', () => LineageEdge.fromJson(e.value as Map<String, dynamic>)))
        .toList();

    final affinityEdges = _parseList(args['affinity_edges'] ?? const [], 'affinity_edges')
        .asMap()
        .entries
        .map((e) => _wrapItem(e.key, 'affinity_edges', () => AffinityEdge.fromJson(e.value as Map<String, dynamic>)))
        .toList();

    final turningPoints = _parseList(args['turning_point_candidates'] ?? const [], 'turning_point_candidates')
        .asMap()
        .entries
        .map((e) => _wrapItem(e.key, 'turning_point_candidates', () => TurningPoint.fromCandidateJson(e.value as Map<String, dynamic>)))
        .toList();

    final followupQuestions = _parseList(args['followup_questions'] ?? const [], 'followup_questions')
        .map((e) => e as String)
        .toList();

    final nodeIds = <String>{};
    for (final node in nodes) {
      if (!nodeIds.add(node.id)) {
        throw GraphParseException('id de nodo duplicado: ${node.id}');
      }
    }
    final nodesById = {for (final node in nodes) node.id: node};

    for (final edge in edges) {
      final source = nodesById[edge.source];
      final target = nodesById[edge.target];
      if (source == null) {
        throw GraphParseException('edge ${edge.id} referencia un nodo origen desconocido: ${edge.source}');
      }
      if (target == null) {
        throw GraphParseException('edge ${edge.id} referencia un nodo destino desconocido: ${edge.target}');
      }
      if (target.type != NodeType.concepto) {
        throw GraphParseException('edge ${edge.id} debe apuntar a un nodo concepto, no a ${edge.target}');
      }
    }

    for (final affinityEdge in affinityEdges) {
      if (!nodeIds.contains(affinityEdge.source)) {
        throw GraphParseException('affinity edge referencia un nodo origen desconocido: ${affinityEdge.source}');
      }
      if (!nodeIds.contains(affinityEdge.target)) {
        throw GraphParseException('affinity edge referencia un nodo destino desconocido: ${affinityEdge.target}');
      }
    }

    for (final turningPoint in turningPoints) {
      final node = nodesById[turningPoint.nodeId];
      if (node == null) {
        throw GraphParseException('turning point candidate referencia un nodo desconocido: ${turningPoint.nodeId}');
      }
      if (node.type != NodeType.concepto) {
        throw GraphParseException('turning point candidate debe ser un nodo concepto: ${turningPoint.nodeId}');
      }
    }

    return CreativeGraph(
      nodes: nodes,
      edges: edges,
      affinityEdges: affinityEdges,
      turningPoints: turningPoints,
      followupQuestions: followupQuestions,
    );
  } on GraphParseException {
    rethrow;
  } catch (e) {
    throw GraphParseException('formato inesperado: $e');
  }
}

List<dynamic> _parseList(dynamic value, String field) {
  if (value is List) return value;
  throw GraphParseException('se esperaba una lista en "$field"');
}

T _wrapItem<T>(int index, String field, T Function() parse) {
  try {
    return parse();
  } on GraphParseException {
    rethrow;
  } catch (e) {
    throw GraphParseException('elemento inválido en "$field" (posición $index): $e');
  }
}

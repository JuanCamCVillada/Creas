import 'dart:collection';

import '../models/creative_graph.dart';
import '../models/node.dart';
import '../models/turning_point.dart';

class CyclicGraphException implements Exception {
  const CyclicGraphException(this.message);
  final String message;

  @override
  String toString() => 'CyclicGraphException: $message';
}

CreativeGraph verifyGraph(CreativeGraph graph) {
  _assertAcyclic(graph);

  final nodesById = {for (final node in graph.nodes) node.id: node};
  final verified = graph.turningPoints
      .map((candidate) => _verifyTurningPoint(candidate, graph, nodesById))
      .where((tp) => tp.isVerified)
      .toList();

  return graph.copyWith(turningPoints: verified);
}

void _assertAcyclic(CreativeGraph graph) {
  final involvedIds = <String>{};
  for (final edge in graph.edges) {
    involvedIds.add(edge.source);
    involvedIds.add(edge.target);
  }

  final inDegree = {for (final id in involvedIds) id: 0};
  final adjacency = {for (final id in involvedIds) id: <String>[]};
  for (final edge in graph.edges) {
    adjacency[edge.source]!.add(edge.target);
    inDegree[edge.target] = (inDegree[edge.target] ?? 0) + 1;
  }

  final queue = Queue<String>()
    ..addAll(inDegree.entries.where((e) => e.value == 0).map((e) => e.key));

  var visited = 0;
  while (queue.isNotEmpty) {
    final id = queue.removeFirst();
    visited++;
    for (final next in adjacency[id] ?? const <String>[]) {
      inDegree[next] = inDegree[next]! - 1;
      if (inDegree[next] == 0) queue.add(next);
    }
  }

  if (visited != involvedIds.length) {
    throw const CyclicGraphException(
        'la línea de tiempo del linaje contiene un ciclo');
  }
}

TurningPoint _verifyTurningPoint(
  TurningPoint candidate,
  CreativeGraph graph,
  Map<String, Node> nodesById,
) {
  final candidateNode = nodesById[candidate.nodeId];
  final incomingEdges =
      graph.edges.where((e) => e.target == candidate.nodeId);

  final incomingFuenteClusters = incomingEdges
      .map((e) => nodesById[e.source])
      .whereType<Node>()
      .where((n) => n.type == NodeType.fuente)
      .map((n) => n.cluster)
      .toSet();

  final upstreamClusters = <String>{...incomingFuenteClusters};
  if (candidateNode != null) {
    upstreamClusters.add(candidateNode.cluster);
  }
  for (final node in incomingEdges
      .map((e) => nodesById[e.source])
      .whereType<Node>()
      .where((n) => n.type == NodeType.concepto)) {
    upstreamClusters.add(node.cluster);
  }

  final downstreamClusters = graph.edges
      .where((e) => e.source == candidate.nodeId)
      .map((e) => nodesById[e.target])
      .whereType<Node>()
      .where((n) => n.type == NodeType.concepto)
      .map((n) => n.cluster)
      .toSet();

  final convergence = incomingFuenteClusters.length >= 2;
  final directionChange =
      downstreamClusters.any((cluster) => !upstreamClusters.contains(cluster));

  return candidate.copyWith(
    convergence: convergence,
    directionChange: directionChange,
  );
}

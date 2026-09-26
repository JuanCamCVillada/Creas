import 'dart:collection';

/// Assigns each node a generation (its longest-path distance from any
/// in-degree-zero node) given a directed acyclic edge set. Used to lay the
/// Árbol Genealógico out in columns, left (oldest) to right (most recent).
///
/// [edges] is a list of (fromId, toId) pairs. Edges whose endpoint isn't in
/// [nodeIds] are ignored (defensive — callers should already filter these).
Map<String, int> computeGenerations({
  required List<String> nodeIds,
  required List<(String, String)> edges,
}) {
  final adjacency = {for (final id in nodeIds) id: <String>[]};
  final inDegree = {for (final id in nodeIds) id: 0};

  for (final (from, to) in edges) {
    if (!adjacency.containsKey(from) || !inDegree.containsKey(to)) continue;
    adjacency[from]!.add(to);
    inDegree[to] = inDegree[to]! + 1;
  }

  final depth = {for (final id in nodeIds) id: 0};
  final remaining = Map.of(inDegree);
  final queue = Queue<String>()
    ..addAll(inDegree.entries.where((e) => e.value == 0).map((e) => e.key));

  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    for (final next in adjacency[current] ?? const <String>[]) {
      if (depth[current]! + 1 > depth[next]!) {
        depth[next] = depth[current]! + 1;
      }
      remaining[next] = remaining[next]! - 1;
      if (remaining[next] == 0) queue.add(next);
    }
  }

  return depth;
}

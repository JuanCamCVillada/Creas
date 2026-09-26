import 'dart:math' as math;
import 'dart:ui';

/// Fruchterman–Reingold-style force-directed layout for Jardín Digital's
/// undirected affinity graph: nodes joined by a strong affinity_weight end
/// up close together, unconnected nodes repel apart, and loose fragments
/// with no edges at all still spread out instead of overlapping.
///
/// Deterministic: initial positions and the whole simulation depend only on
/// [nodeIds] and [edges], never on wall-clock time or `Random()`, so the
/// same graph always relaxes to the same layout (and is testable).
Map<String, Offset> computeForceLayout({
  required List<String> nodeIds,
  required List<(String, String, double)> edges,
  int iterations = 300,
  double width = 900,
  double height = 700,
}) {
  if (nodeIds.isEmpty) return {};

  final area = width * height;
  final k = math.sqrt(area / nodeIds.length);

  final positions = <String, Offset>{
    for (final id in nodeIds)
      id: Offset(
        (id.hashCode.abs() % 1000) / 1000 * width,
        ((id.hashCode.abs() ~/ 1000) % 1000) / 1000 * height,
      ),
  };

  final validEdges = [
    for (final edge in edges)
      if (positions.containsKey(edge.$1) && positions.containsKey(edge.$2)) edge,
  ];

  var temperature = width / 10;
  for (var iter = 0; iter < iterations; iter++) {
    final displacement = {for (final id in nodeIds) id: Offset.zero};

    for (var i = 0; i < nodeIds.length; i++) {
      for (var j = i + 1; j < nodeIds.length; j++) {
        final a = nodeIds[i];
        final b = nodeIds[j];
        final delta = positions[a]! - positions[b]!;
        final dist = math.max(delta.distance, 0.01);
        final force = (k * k) / dist;
        final dir = delta / dist;
        displacement[a] = displacement[a]! + dir * force;
        displacement[b] = displacement[b]! - dir * force;
      }
    }

    for (final (from, to, weight) in validEdges) {
      final delta = positions[to]! - positions[from]!;
      final dist = math.max(delta.distance, 0.01);
      final force = (dist * dist) / k * (0.4 + weight.clamp(0.0, 1.0));
      final dir = delta / dist;
      displacement[from] = displacement[from]! + dir * force;
      displacement[to] = displacement[to]! - dir * force;
    }

    for (final id in nodeIds) {
      final disp = displacement[id]!;
      final dist = disp.distance;
      if (dist > 0.01) {
        positions[id] = positions[id]! + disp / dist * math.min(dist, temperature);
      }
    }

    temperature *= 0.95;
  }

  return positions;
}

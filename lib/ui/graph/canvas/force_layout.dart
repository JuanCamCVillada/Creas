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
  double? minSeparation,
}) {
  if (nodeIds.isEmpty) return {};

  final area = width * height;
  // k is the algorithm's equilibrium spacing for two unconnected nodes.
  // Deriving it purely from area/n can settle below a node's own rendered
  // footprint for small graphs — [minSeparation] (typically the node
  // widget's own size) is a floor so boxes never overlap even when they
  // don't collide outright.
  final k = math.max(math.sqrt(area / nodeIds.length), minSeparation ?? 0);

  // The frame nodes are clamped to each iteration must be big enough to
  // actually fit n nodes spaced k apart — when [minSeparation] pushes k
  // above what the caller's width/height imply, clamping to the raw
  // width/height would squeeze nodes back together and defeat
  // minSeparation entirely. Grow the frame to whichever is larger.
  final fitSpan = k * math.sqrt(nodeIds.length) * 1.2;
  final frameWidth = math.max(width, fitSpan);
  final frameHeight = math.max(height, fitSpan);

  // Seed on a circle, one node per index — this guarantees every node
  // starts at a strictly distinct point regardless of what its id hashes
  // to. Seeding from id.hashCode instead let two ids whose hash collided
  // (mod the seed grid) start exactly coincident; repulsion between two
  // coincident points has an undefined direction (delta is Offset.zero),
  // so they never separated and rendered stacked on top of each other.
  final center = Offset(frameWidth / 2, frameHeight / 2);
  final radius = math.min(frameWidth, frameHeight) * 0.35;
  final positions = <String, Offset>{
    for (var i = 0; i < nodeIds.length; i++)
      nodeIds[i]: center +
          Offset(
            radius * math.cos(2 * math.pi * i / nodeIds.length),
            radius * math.sin(2 * math.pi * i / nodeIds.length),
          ),
  };

  final validEdges = [
    for (final edge in edges)
      if (positions.containsKey(edge.$1) && positions.containsKey(edge.$2)) edge,
  ];

  var temperature = frameWidth / 10;
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
      var next = positions[id]!;
      if (dist > 0.01) {
        next = next + disp / dist * math.min(dist, temperature);
      }
      // Classic Fruchterman–Reingold clips positions to the frame each
      // iteration. Without this, repulsion between unconnected nodes has
      // nothing to balance against (no centering/attractive force at long
      // range), so the whole graph slowly drifts outward for the entire
      // run instead of settling near k — the frame is what makes it an
      // equilibrium instead of an unbounded expansion.
      positions[id] = Offset(
        next.dx.clamp(0.0, frameWidth),
        next.dy.clamp(0.0, frameHeight),
      );
    }

    temperature *= 0.95;
  }

  return positions;
}

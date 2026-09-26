import 'dart:math' as math;
import 'dart:ui';

/// Jardín Digital's layout: nodes joined by at least one affinity edge are
/// "connected" and get organized into clean columns by cluster — the same
/// tidy row/column look as Árbol Genealógico's generation columns, instead
/// of a force-directed scatter. Nodes with no affinity edge at all are
/// "loose" and pushed onto concentric orbit rings around that connected
/// mass, like planets around it — further from the center, never mixed
/// into the tidy columns they don't belong to.
///
/// Deterministic: clusters and rings are ordered by id, never by insertion
/// order or randomness, so the same graph always lays out the same way.
Map<String, Offset> computeClusterOrbitLayout({
  required List<String> nodeIds,
  required Map<String, String> clusterOf,
  required List<(String, String, double)> affinityEdges,
  double columnSpacing = 210,
  double rowSpacing = 150,
  double orbitPadding = 260,
  double orbitRingSpacing = 190,
  double orbitNodeSpacing = 190,
}) {
  if (nodeIds.isEmpty) return {};

  final connected = <String>{};
  for (final (a, b, _) in affinityEdges) {
    connected.add(a);
    connected.add(b);
  }

  final connectedIds = nodeIds.where(connected.contains).toList();
  final looseIds = nodeIds.where((id) => !connected.contains(id)).toList()..sort();

  final byCluster = <String, List<String>>{};
  for (final id in connectedIds) {
    byCluster.putIfAbsent(clusterOf[id] ?? '', () => []).add(id);
  }
  for (final ids in byCluster.values) {
    ids.sort();
  }
  final clusters = byCluster.keys.toList()..sort();

  final positions = <String, Offset>{};
  for (var col = 0; col < clusters.length; col++) {
    final ids = byCluster[clusters[col]]!;
    final x = col * columnSpacing;
    for (var row = 0; row < ids.length; row++) {
      positions[ids[row]] = Offset(x, row * rowSpacing);
    }
  }

  final center = positions.isEmpty
      ? Offset.zero
      : positions.values.reduce((a, b) => a + b) / positions.length.toDouble();
  final massRadius = positions.isEmpty
      ? 0.0
      : positions.values
          .map((o) => (o - center).distance)
          .reduce((a, b) => a > b ? a : b);

  var ringRadius = massRadius + orbitPadding;
  var placedInRing = 0;
  var ringCapacity = math.max(6, (2 * math.pi * ringRadius / orbitNodeSpacing).floor());
  for (final id in looseIds) {
    if (placedInRing >= ringCapacity) {
      ringRadius += orbitRingSpacing;
      ringCapacity = math.max(6, (2 * math.pi * ringRadius / orbitNodeSpacing).floor());
      placedInRing = 0;
    }
    final angle = 2 * math.pi * placedInRing / ringCapacity;
    positions[id] = center + Offset(ringRadius * math.cos(angle), ringRadius * math.sin(angle));
    placedInRing++;
  }

  return positions;
}

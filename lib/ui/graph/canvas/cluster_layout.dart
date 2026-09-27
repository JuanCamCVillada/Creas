import 'dart:math' as math;
import 'dart:ui';

/// The full result of [computeClusterOrbitLayout]: node positions plus the
/// geometry ([center], [ringRadii]) the caller needs to actually paint the
/// orbit rings as a visible boundary — without this, the ring structure
/// the layout computes is invisible to the viewer, who just sees scattered
/// nodes with no indication that "loose" ones are meant to read as
/// orbiting something.
class ClusterOrbitLayout {
  const ClusterOrbitLayout({
    required this.positions,
    required this.center,
    required this.ringRadii,
  });

  final Map<String, Offset> positions;
  final Offset center;

  /// One radius per ring actually used (empty if there are no loose nodes).
  final List<double> ringRadii;
}

/// Jardín Digital's layout: nodes joined by at least one affinity edge are
/// "connected" and get organized into clean columns by cluster — the same
/// tidy row/column look as Árbol Genealógico's generation columns, instead
/// of a force-directed scatter. Nodes with no affinity edge at all are
/// "loose" and pushed onto concentric orbit rings around that connected
/// mass, like planets around it — further from the center, never mixed
/// into the tidy columns they don't belong to. Loose nodes keep their
/// cluster's own adjacency on the ring (grouped by cluster, then id) so
/// members of the same cluster still land near each other even when none
/// of them have an affinity edge.
///
/// Deterministic: clusters and rings are ordered by id, never by insertion
/// order or randomness, so the same graph always lays out the same way.
ClusterOrbitLayout computeClusterOrbitLayout({
  required List<String> nodeIds,
  required Map<String, String> clusterOf,
  required List<(String, String, double)> affinityEdges,
  double columnSpacing = 210,
  double rowSpacing = 150,
  double orbitPadding = 260,
  double orbitRingSpacing = 190,
  double orbitNodeSpacing = 190,
}) {
  assert(columnSpacing > 0, 'columnSpacing must be positive');
  assert(rowSpacing > 0, 'rowSpacing must be positive');
  assert(orbitPadding >= 0, 'orbitPadding must not be negative');
  assert(orbitRingSpacing > 0, 'orbitRingSpacing must be positive');
  assert(orbitNodeSpacing > 0, 'orbitNodeSpacing must be positive');

  if (nodeIds.isEmpty) {
    return const ClusterOrbitLayout(positions: {}, center: Offset.zero, ringRadii: []);
  }

  final connected = <String>{};
  for (final (a, b, _) in affinityEdges) {
    connected.add(a);
    connected.add(b);
  }

  final connectedIds = nodeIds.where(connected.contains).toList();
  // Grouped by cluster first, id second — so loose members of the same
  // cluster still land adjacent on a ring instead of scattering wherever
  // their bare id happens to sort them.
  final looseIds = nodeIds.where((id) => !connected.contains(id)).toList()
    ..sort((a, b) {
      final clusterCompare = (clusterOf[a] ?? '').compareTo(clusterOf[b] ?? '');
      return clusterCompare != 0 ? clusterCompare : a.compareTo(b);
    });

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

  // First pass: assign each loose node to a ring using the same growth
  // rule as before, but only to learn how many nodes actually land in
  // each ring — angle spacing (second pass) then divides by that real
  // count, not the ring's theoretical capacity, so e.g. 2 loose nodes on
  // an 8-capacity ring land 180° apart instead of bunched at 0°/45°.
  final ringRadii = <double>[];
  final ringOfIndex = <int>[];
  var ringRadius = massRadius + orbitPadding;
  var ringIndex = 0;
  var placedInRing = 0;
  var ringCapacity = math.max(6, (2 * math.pi * ringRadius / orbitNodeSpacing).floor());
  for (var i = 0; i < looseIds.length; i++) {
    if (placedInRing >= ringCapacity) {
      ringRadius += orbitRingSpacing;
      ringIndex++;
      ringCapacity = math.max(6, (2 * math.pi * ringRadius / orbitNodeSpacing).floor());
      placedInRing = 0;
    }
    if (ringRadii.length == ringIndex) ringRadii.add(ringRadius);
    ringOfIndex.add(ringIndex);
    placedInRing++;
  }

  final countPerRing = <int, int>{};
  for (final r in ringOfIndex) {
    countPerRing[r] = (countPerRing[r] ?? 0) + 1;
  }
  final placedSoFarPerRing = <int, int>{};
  for (var i = 0; i < looseIds.length; i++) {
    final r = ringOfIndex[i];
    final indexInRing = placedSoFarPerRing[r] ?? 0;
    placedSoFarPerRing[r] = indexInRing + 1;
    final countInRing = countPerRing[r]!;
    final angle = 2 * math.pi * indexInRing / countInRing;
    final radius = ringRadii[r];
    positions[looseIds[i]] =
        center + Offset(radius * math.cos(angle), radius * math.sin(angle));
  }

  return ClusterOrbitLayout(positions: positions, center: center, ringRadii: ringRadii);
}

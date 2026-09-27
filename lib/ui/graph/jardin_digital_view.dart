// lib/ui/graph/jardin_digital_view.dart
import 'package:flutter/material.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import '../theme/hud_alerts.dart';
import '../theme/hud_text.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_widgets.dart';
import 'canvas/cluster_layout.dart';
import 'canvas/graph_canvas.dart';
import 'canvas/graph_legend.dart';
import 'canvas/node_cell.dart';
import 'canvas/node_shapes.dart';
import 'graph_status.dart';
import 'node_detail_sheet.dart';
import 'node_icons.dart';


/// A node counted as a "hub" gets the same glow treatment Árbol reserves
/// for its own special nodes (a turning point, a synthesis sink) — here
/// the equivalent standout is a node many other nodes are actually
/// affinity-connected to, real signal rather than decoration.
const _hubAffinityThreshold = 3;

class JardinDigitalView extends StatefulWidget {
  const JardinDigitalView({
    super.key,
    required this.graph,
    this.onNodeSelected,
    this.showLegend = true,
  });

  final CreativeGraph graph;

  /// On a wide (desktop/web) layout, GraphViewScreen renders a persistent
  /// detail panel instead of a modal sheet — passing this makes a node tap
  /// hand the built [NodeDetailSheet] up to that panel instead of opening
  /// a bottom sheet. Null (the default, used on narrow/mobile layouts)
  /// keeps the modal behavior.
  final ValueChanged<Widget>? onNodeSelected;

  /// false on the wide dashboard layout, which renders its own full-width
  /// legend bar below the canvas instead (via [legendShapes]/[legendLines])
  /// — avoids showing the key twice.
  final bool showLegend;

  static List<GraphLegendShape> legendShapes(HudColors c) => [
        GraphLegendShape(kind: NodeShapeKind.hexagon, label: 'FUENTE', color: c.unit),
        GraphLegendShape(kind: NodeShapeKind.circle, label: 'CONCEPTO', color: c.struct),
      ];

  static List<GraphLegendLine> legendLines(HudColors c) => [
        GraphLegendLine(label: 'AFINIDAD FUERTE', dashed: false, color: c.data),
        GraphLegendLine(label: 'AFINIDAD DÉBIL', dashed: true, color: c.data),
      ];

  @override
  State<JardinDigitalView> createState() => _JardinDigitalViewState();
}

class _JardinDigitalViewState extends State<JardinDigitalView> {
  final Set<String> _rejectedIds = {};

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final graph = widget.graph;
    final visibleNodes = graph.nodes.where((n) => !_rejectedIds.contains(n.id)).toList();

    if (visibleNodes.isEmpty) {
      return Container(
        color: c.bg,
        child: Center(
          child: HudChamferedBox(
            fill: Colors.transparent,
            borderColor: c.grid,
            borderWidth: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('庭', style: HudText.operativa(c.textDim, size: 24)),
                const SizedBox(height: 8),
                Text('EL JARDÍN ESTÁ VACÍO', style: HudText.operativa(c.textDim, size: 12)),
              ],
            ),
          ),
        ),
      );
    }

    final nodesById = {for (final node in visibleNodes) node.id: node};
    final codeOf = <String, String>{};
    var fuenteCount = 0, conceptoCount = 0;
    for (final node in visibleNodes) {
      codeOf[node.id] = node.type == model.NodeType.fuente
          ? 'F-${(++fuenteCount).toString().padLeft(2, '0')}'
          : 'C-${(++conceptoCount).toString().padLeft(2, '0')}';
    }

    final visibleIds = nodesById.keys.toSet();
    final affinityEdges = graph.affinityEdges
        .where((e) => visibleIds.contains(e.source) && visibleIds.contains(e.target))
        .toList();

    // One pass, reused by the node builder, the hub-glow check, and the
    // detail sheet stat — avoids re-scanning every affinity edge per node
    // per rebuild (a real cost while dragging a node, since GraphCanvas
    // rebuilds every cell on each drag frame).
    final affinityCountOf = <String, int>{};
    for (final edge in affinityEdges) {
      affinityCountOf[edge.source] = (affinityCountOf[edge.source] ?? 0) + 1;
      affinityCountOf[edge.target] = (affinityCountOf[edge.target] ?? 0) + 1;
    }
    final connectedIds = affinityCountOf.keys.toSet();

    // Same rendering engine as Árbol Genealógico (GraphCanvas + shared
    // GraphNodeCell), but a different layout: nodes sharing a real
    // affinity_weight edge are organized into clean columns by cluster —
    // the same tidy row/column look as the generation columns in Árbol —
    // while nodes with no affinity edge at all orbit that connected mass
    // further out, like loose planets, instead of being scattered at
    // random or forced to overlap it.
    final layout = computeClusterOrbitLayout(
      nodeIds: visibleNodes.map((n) => n.id).toList(),
      clusterOf: {for (final node in visibleNodes) node.id: node.cluster},
      affinityEdges: [for (final edge in affinityEdges) (edge.source, edge.target, edge.weight)],
    );

    // The first (alphabetically) connected node in each cluster's column
    // gets the cluster's name as a header caption — mirrors Árbol's
    // generation-column headers ("G-2"), so a column's grouping is
    // legible without tapping every node in it to read the tiny cluster
    // line inside GraphNodeCell.
    final clusterHeaderFor = <String, String>{};
    final connectedByCluster = <String, List<String>>{};
    for (final id in visibleNodes.map((n) => n.id)) {
      if (!connectedIds.contains(id)) continue;
      connectedByCluster.putIfAbsent(nodesById[id]!.cluster, () => []).add(id);
    }
    for (final entry in connectedByCluster.entries) {
      entry.value.sort();
      clusterHeaderFor[entry.value.first] = entry.key.toUpperCase();
    }

    final edges = [
      for (final edge in affinityEdges)
        GraphCanvasEdge(
          fromId: edge.source,
          toId: edge.target,
          dashed: edge.weight < 0.4,
          // Weight now reads as both opacity AND thickness — a single
          // alpha-on-blue value is too subtle to tell "strong" from
          // "weak" apart at a glance, especially at typical zoomed-out
          // scale (per the hud-tactico rule that color is never the only
          // signal).
          color: c.data.withValues(alpha: 0.25 + edge.weight.clamp(0, 1) * 0.65),
          width: 1.1 + edge.weight.clamp(0, 1) * 2.1,
        ),
    ];

    final lowConfidence = lowConfidenceFuentes(visibleNodes);
    final graphStatus = statusForLowConfidence(lowConfidence);

    return Container(
      color: c.bg,
      child: Stack(
        children: [
          GraphCanvas(
            nodeIds: visibleNodes.map((n) => n.id).toList(),
            initialPositions: layout.positions,
            edges: edges,
            nodeSize: kGraphNodeCellSize,
            edgeColor: c.data,
            backgroundBuilder: (positions) {
              if (layout.ringRadii.isEmpty) return const SizedBox.shrink();
              final anchorId = connectedIds.isNotEmpty
                  ? connectedIds.first
                  : visibleNodes.first.id;
              final rawAnchor = layout.positions[anchorId];
              final drawnAnchor = positions[anchorId];
              if (rawAnchor == null || drawnAnchor == null) return const SizedBox.shrink();
              final shiftedCenter = layout.center + (drawnAnchor - rawAnchor);
              return CustomPaint(
                painter: _OrbitRingPainter(center: shiftedCenter, radii: layout.ringRadii, color: c.textDim),
              );
            },
            nodeBuilder: (context, id) {
              final node = nodesById[id]!;
              final isFuente = node.type == model.NodeType.fuente;
              final affinityCount = affinityCountOf[id] ?? 0;
              return GraphNodeCell(
                label: node.label,
                cluster: node.cluster,
                code: codeOf[id]!,
                shapeKind: isFuente ? NodeShapeKind.hexagon : NodeShapeKind.circle,
                fill: isFuente ? c.unit : c.struct,
                icon: iconForNode(node),
                isSugerido: node.origin == model.NodeOrigin.sugerido,
                generationLabel: clusterHeaderFor[id] ??
                    (connectedIds.contains(id) ? null : '· SUELTO ·'),
                glow: affinityCount >= _hubAffinityThreshold,
                onTap: () {
                  final detail = NodeDetailSheet(
                    node: node,
                    code: codeOf[id],
                    kindLabel: isFuente ? 'FUENTE' : 'CONCEPTO',
                    glyph: isFuente ? '源' : '概',
                    stats: [
                      NodeStat('AFINIDADES', '$affinityCount conexiones'),
                      NodeStat('CLUSTER', '${connectedByCluster[node.cluster]?.length ?? 0} nodos'),
                      NodeStat('PESO', node.confidence?.toStringAsFixed(2) ?? '—'),
                    ],
                  );
                  if (widget.onNodeSelected != null) {
                    widget.onNodeSelected!(detail);
                  } else {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => detail,
                    );
                  }
                },
                // Parity with Árbol Genealógico's own accept/reject wiring
                // (arbol_genealogico_view.dart): accept has no behavior
                // implemented yet there either (a stub), reject removes
                // the node from the visible set.
                onAccept: node.origin == model.NodeOrigin.sugerido ? () {} : null,
                onReject: node.origin == model.NodeOrigin.sugerido
                    ? () => setState(() => _rejectedIds.add(id))
                    : null,
              );
            },
          ),
          // Overlays are purely informational (no controls of their own on
          // this screen) — IgnorePointer lets taps on a node that happens
          // to render underneath one reach the canvas instead of the
          // overlay's opaque paint absorbing the hit.
          Positioned(
            top: 12,
            right: 12,
            child: IgnorePointer(child: HudStatusBadge(status: graphStatus)),
          ),
          if (lowConfidence.isNotEmpty)
            Positioned(
              top: 52,
              right: 12,
              left: 12,
              child: IgnorePointer(
                child: HudHazardBanner(
                  status: HudStatus.precaucion,
                  glyph: '注意',
                  title: lowConfidenceBannerTitle(lowConfidence, codeOf),
                  subtitle: 'Revisar antes de derivar conceptos desde aquí.',
                ),
              ),
            ),
          if (widget.showLegend)
            Positioned(
              left: 12,
              bottom: 12,
              child: IgnorePointer(
                child: GraphLegend(
                  shapes: JardinDigitalView.legendShapes(c),
                  lines: JardinDigitalView.legendLines(c),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Paints the concentric orbit rings [computeClusterOrbitLayout] computes
/// but doesn't draw itself — without this the ring geometry is invisible
/// and "· SUELTO ·" reads as an arbitrary caption rather than an actual
/// boundary separating loose nodes from the connected mass.
class _OrbitRingPainter extends CustomPainter {
  _OrbitRingPainter({required this.center, required this.radii, required this.color});

  final Offset center;
  final List<double> radii;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final radius in radii) {
      final path = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        var draw = true;
        while (distance < metric.length) {
          final next = distance + (draw ? 8.0 : 6.0);
          if (draw) {
            canvas.drawPath(
              metric.extractPath(distance, next.clamp(0, metric.length)),
              paint,
            );
          }
          distance = next;
          draw = !draw;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.radii != radii || oldDelegate.color != color;
}

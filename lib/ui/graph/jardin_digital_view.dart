// lib/ui/graph/jardin_digital_view.dart
import 'package:flutter/material.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import '../theme/hud_alerts.dart';
import '../theme/hud_tokens.dart';
import 'canvas/cluster_layout.dart';
import 'canvas/graph_canvas.dart';
import 'canvas/graph_legend.dart';
import 'canvas/node_cell.dart';
import 'canvas/node_shapes.dart';
import 'node_detail_sheet.dart';
import 'node_icons.dart';

const _nodeCellSize = Size(150, 132);

class JardinDigitalView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    if (graph.nodes.isEmpty) {
      return Container(
        color: c.bg,
        child: Center(
          child: Text('El jardín está vacío.', style: TextStyle(color: c.textDim)),
        ),
      );
    }

    final nodesById = {for (final node in graph.nodes) node.id: node};
    final codeOf = <String, String>{};
    var fuenteCount = 0, conceptoCount = 0;
    for (final node in graph.nodes) {
      codeOf[node.id] = node.type == model.NodeType.fuente
          ? 'F-${(++fuenteCount).toString().padLeft(2, '0')}'
          : 'C-${(++conceptoCount).toString().padLeft(2, '0')}';
    }

    // Same rendering engine as Árbol Genealógico (GraphCanvas + shared
    // GraphNodeCell), but a different layout: nodes sharing a real
    // affinity_weight edge are organized into clean columns by cluster —
    // the same tidy row/column look as the generation columns in Árbol —
    // while nodes with no affinity edge at all orbit that connected mass
    // further out, like loose planets, instead of being scattered at
    // random or forced to overlap it.
    final connectedIds = <String>{
      for (final edge in graph.affinityEdges) ...[edge.source, edge.target],
    };
    final positions = computeClusterOrbitLayout(
      nodeIds: graph.nodes.map((n) => n.id).toList(),
      clusterOf: {for (final node in graph.nodes) node.id: node.cluster},
      affinityEdges: [
        for (final edge in graph.affinityEdges) (edge.source, edge.target, edge.weight),
      ],
    );

    final edges = [
      for (final edge in graph.affinityEdges)
        GraphCanvasEdge(
          fromId: edge.source,
          toId: edge.target,
          dashed: edge.weight < 0.4,
          color: c.data.withValues(alpha: 0.35 + edge.weight.clamp(0, 1) * 0.5),
        ),
    ];

    final lowConfidenceFuentes = graph.nodes
        .where((n) =>
            n.type == model.NodeType.fuente &&
            n.confidence != null &&
            n.confidence! < 0.5)
        .toList();
    final graphStatus =
        lowConfidenceFuentes.isEmpty ? HudStatus.nominal : HudStatus.precaucion;

    return Container(
      color: c.bg,
      child: Stack(
        children: [
          GraphCanvas(
            nodeIds: graph.nodes.map((n) => n.id).toList(),
            initialPositions: positions,
            edges: edges,
            nodeSize: _nodeCellSize,
            edgeColor: c.data,
            nodeBuilder: (context, id) {
              final node = nodesById[id]!;
              final isFuente = node.type == model.NodeType.fuente;
              final affinityCount = graph.affinityEdges
                  .where((e) => e.source == id || e.target == id)
                  .length;
              return GraphNodeCell(
                label: node.label,
                cluster: node.cluster,
                code: codeOf[id]!,
                shapeKind: isFuente ? NodeShapeKind.hexagon : NodeShapeKind.circle,
                fill: isFuente ? c.unit : c.struct,
                icon: iconForNode(node),
                isSugerido: node.origin == model.NodeOrigin.sugerido,
                generationLabel: connectedIds.contains(id) ? null : '· SUELTO ·',
                onTap: () {
                  final detail = NodeDetailSheet(
                    node: node,
                    code: codeOf[id],
                    kindLabel: isFuente ? 'FUENTE' : 'CONCEPTO',
                    glyph: isFuente ? '源' : '概',
                    stats: [
                      NodeStat('AFINIDADES', '$affinityCount conexiones'),
                      NodeStat('PESO', node.confidence?.toStringAsFixed(2) ?? '—'),
                    ],
                  );
                  if (onNodeSelected != null) {
                    onNodeSelected!(detail);
                  } else {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => detail,
                    );
                  }
                },
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
          if (lowConfidenceFuentes.isNotEmpty)
            Positioned(
              top: 52,
              right: 12,
              left: 12,
              child: IgnorePointer(
                child: HudHazardBanner(
                  status: HudStatus.precaucion,
                  glyph: '注意',
                  title:
                      'FUENTE ${codeOf[lowConfidenceFuentes.first.id]} CON CONFIANZA BAJA '
                      '(${lowConfidenceFuentes.first.confidence!.toStringAsFixed(2)})',
                  subtitle: 'Revisar antes de derivar conceptos desde aquí.',
                ),
              ),
            ),
          if (showLegend)
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

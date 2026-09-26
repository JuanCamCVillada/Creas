// lib/ui/graph/jardin_digital_view.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import '../theme/hud_tokens.dart';
import 'canvas/force_layout.dart';
import 'canvas/graph_canvas.dart';
import 'canvas/node_cell.dart';
import 'canvas/node_shapes.dart';
import 'node_detail_sheet.dart';
import 'node_icons.dart';

const _nodeCellSize = Size(150, 132);

class JardinDigitalView extends StatelessWidget {
  const JardinDigitalView({super.key, required this.graph});

  final CreativeGraph graph;

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
    // GraphNodeCell), but a different layout: Jardín is an undirected
    // exploratory map, so nodes are relaxed by their real affinity_weight
    // instead of assigned to generational columns — strongly related nodes
    // end up near each other, loose fragments spread out on their own.
    // Never let the algorithm's equilibrium spacing settle below the node
    // cell's own footprint — otherwise chips visually overlap even when
    // their center positions aren't exactly coincident.
    final minSeparation = math.max(_nodeCellSize.width, _nodeCellSize.height) * 1.5;
    // Size the starting area so it's already consistent with that spacing
    // (area ≈ minSeparation² × n) — an area sized for a smaller equilibrium
    // distance forces every node to travel far beyond its seed position to
    // reach minSeparation, which can push a small graph well outside any
    // fixed viewport.
    final span = minSeparation * math.sqrt(graph.nodes.length);
    final positions = computeForceLayout(
      nodeIds: graph.nodes.map((n) => n.id).toList(),
      edges: [
        for (final edge in graph.affinityEdges) (edge.source, edge.target, edge.weight),
      ],
      width: span,
      height: span,
      minSeparation: minSeparation,
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

    return Container(
      color: c.bg,
      child: GraphCanvas(
        nodeIds: graph.nodes.map((n) => n.id).toList(),
        initialPositions: positions,
        edges: edges,
        nodeSize: _nodeCellSize,
        edgeColor: c.data,
        nodeBuilder: (context, id) {
          final node = nodesById[id]!;
          final isFuente = node.type == model.NodeType.fuente;
          return GraphNodeCell(
            label: node.label,
            cluster: node.cluster,
            code: codeOf[id]!,
            shapeKind: isFuente ? NodeShapeKind.hexagon : NodeShapeKind.circle,
            fill: isFuente ? c.unit : c.struct,
            icon: iconForNode(node),
            isSugerido: node.origin == model.NodeOrigin.sugerido,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => NodeDetailSheet(node: node),
            ),
          );
        },
      ),
    );
  }
}

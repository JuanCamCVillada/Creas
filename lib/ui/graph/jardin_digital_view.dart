// lib/ui/graph/jardin_digital_view.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import 'canvas/graph_canvas.dart';
import 'canvas/node_shapes.dart';
import 'node_detail_sheet.dart';
import 'node_icons.dart';

const _nodeCellSize = Size(150, 132);
const _cellSpacing = 190.0;

class JardinDigitalView extends StatelessWidget {
  const JardinDigitalView({super.key, required this.graph});

  final CreativeGraph graph;

  /// Deterministic cluster scatter: clusters are packed into a grid sized
  /// to however many distinct clusters this graph actually has (not a fixed
  /// grid — a graph with 2 clusters shouldn't scatter them across a 4x4
  /// space meant for 16), with a small per-node jitter so nodes in the same
  /// cluster don't stack exactly on top of each other.
  Offset _seedFor(int clusterIndex, int gridColumns, String nodeId) {
    final col = clusterIndex % gridColumns;
    final row = clusterIndex ~/ gridColumns;
    final jitterSeed = nodeId.hashCode.abs();
    final jitterX = (jitterSeed % 61) - 30;
    final jitterY = ((jitterSeed ~/ 61) % 61) - 30;
    return Offset(
      col * _cellSpacing + jitterX,
      row * _cellSpacing + jitterY,
    );
  }

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

    final clusters = graph.nodes.map((n) => n.cluster).toSet().toList()..sort();
    final clusterIndex = {for (var i = 0; i < clusters.length; i++) clusters[i]: i};
    final gridColumns = math.max(1, math.sqrt(clusters.length).ceil());
    final positions = {
      for (final node in graph.nodes)
        node.id: _seedFor(clusterIndex[node.cluster]!, gridColumns, node.id),
    };

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
          return _JardinNodeCell(
            node: node,
            code: codeOf[id]!,
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

class _JardinNodeCell extends StatelessWidget {
  const _JardinNodeCell({required this.node, required this.code, required this.onTap});

  final model.Node node;
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final isSugerido = node.origin == model.NodeOrigin.sugerido;
    final isFuente = node.type == model.NodeType.fuente;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NodeShape(
            kind: isFuente ? NodeShapeKind.hexagon : NodeShapeKind.circle,
            size: 52,
            fill: isFuente ? c.unit : c.struct,
            border: isSugerido ? c.text2 : (isFuente ? c.unit : c.struct),
            dashedBorder: isSugerido,
            child: Icon(iconForNode(node), size: 16, color: c.text),
          ),
          const SizedBox(height: 4),
          Text(code, style: HudText.terminal(c.id, size: 10)),
          Text(
            node.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            node.cluster,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HudText.terminal(c.textDim, size: 9),
          ),
        ],
      ),
    );
  }
}

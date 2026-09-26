// lib/ui/graph/arbol_genealogico_view.dart
import 'package:flutter/material.dart';

import '../../models/creative_graph.dart';
import '../../models/lineage_edge.dart';
import '../../models/node.dart' as model;
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import 'canvas/graph_canvas.dart';
import 'canvas/lineage_layout.dart';
import 'canvas/node_shapes.dart';
import 'node_detail_sheet.dart';
import 'node_icons.dart';
import 'turning_point_badge.dart';

const _rootId = 'root-tu';
const _nodeCellSize = Size(150, 156);
const _columnSpacing = 210.0;
const _rowSpacing = 150.0;

enum _NodeKind { root, fuente, turningPoint, sink, concepto }

class ArbolGenealogicoView extends StatefulWidget {
  const ArbolGenealogicoView({super.key, required this.graph});

  final CreativeGraph graph;

  @override
  State<ArbolGenealogicoView> createState() => _ArbolGenealogicoViewState();
}

class _ArbolGenealogicoViewState extends State<ArbolGenealogicoView> {
  final Set<String> _rejectedIds = {};

  void _showEvidence(String evidence) {
    final c = HudColors.consola;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.panel,
        title: Text('PUNTO DE INFLEXIÓN', style: TextStyle(color: c.caution)),
        content: Text(evidence, style: TextStyle(color: c.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar', style: TextStyle(color: c.sys)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final graph = widget.graph;
    final visibleNodes =
        graph.nodes.where((n) => !_rejectedIds.contains(n.id)).toList();
    final nodesById = {for (final node in visibleNodes) node.id: node};

    final turningPointIds = graph.turningPoints
        .where((tp) => tp.isVerified)
        .map((tp) => tp.nodeId)
        .toSet();
    final evidenceByNodeId = {
      for (final tp in graph.turningPoints.where((tp) => tp.isVerified))
        tp.nodeId: tp.evidence,
    };
    final hasOutgoingLineageEdge = <String>{
      for (final edge in graph.edges) edge.source,
    };

    // Assign each visible node a kind, driving both its shape and its id code.
    final kindOf = <String, _NodeKind>{};
    final codeOf = <String, String>{};
    var fuenteCount = 0, conceptoCount = 0, infCount = 0, sinkCount = 0;
    for (final node in visibleNodes) {
      if (node.type == model.NodeType.fuente) {
        kindOf[node.id] = _NodeKind.fuente;
        codeOf[node.id] = 'F-${(++fuenteCount).toString().padLeft(2, '0')}';
      } else if (turningPointIds.contains(node.id)) {
        kindOf[node.id] = _NodeKind.turningPoint;
        codeOf[node.id] = 'INF-${(++infCount).toString().padLeft(2, '0')}';
      } else if (!hasOutgoingLineageEdge.contains(node.id)) {
        kindOf[node.id] = _NodeKind.sink;
        codeOf[node.id] = 'S-${(++sinkCount).toString().padLeft(2, '0')}';
      } else {
        kindOf[node.id] = _NodeKind.concepto;
        codeOf[node.id] = 'C-${(++conceptoCount).toString().padLeft(2, '0')}';
      }
    }

    // Directed edges for layout + drawing: the referente pedigree (display
    // edges, dashed) plus the verified concept lineage (solid, except
    // "inspira" which reads as a looser, dashed influence).
    final displayEdges = <(String, String, LineageRelation?)>[];
    for (final node in visibleNodes.where((n) => n.level == 1)) {
      displayEdges.add((_rootId, node.id, null));
    }
    for (final node in visibleNodes.where((n) => n.level == 2)) {
      final parentId = node.referenteOf;
      if (parentId != null && nodesById.containsKey(parentId)) {
        displayEdges.add((parentId, node.id, null));
      }
    }
    for (final edge in graph.edges) {
      if (nodesById.containsKey(edge.source) && nodesById.containsKey(edge.target)) {
        displayEdges.add((edge.source, edge.target, edge.relation));
      }
    }

    final nodeIds = [_rootId, ...visibleNodes.map((n) => n.id)];
    final generations = computeGenerations(
      nodeIds: nodeIds,
      edges: [for (final (from, to, _) in displayEdges) (from, to)],
    );

    // Stack nodes within each generation column, in a stable order.
    final byGeneration = <int, List<String>>{};
    for (final id in nodeIds) {
      byGeneration.putIfAbsent(generations[id] ?? 0, () => []).add(id);
    }
    final positions = <String, Offset>{};
    for (final entry in byGeneration.entries) {
      final x = 120.0 + entry.key * _columnSpacing;
      for (var i = 0; i < entry.value.length; i++) {
        positions[entry.value[i]] = Offset(x, 100.0 + i * _rowSpacing);
      }
    }

    final canvasEdges = [
      for (final (from, to, relation) in displayEdges)
        GraphCanvasEdge(
          fromId: from,
          toId: to,
          dashed: relation == null || relation == LineageRelation.inspira,
        ),
    ];

    return Container(
      color: c.bg,
      child: GraphCanvas(
        nodeIds: nodeIds,
        initialPositions: positions,
        edges: canvasEdges,
        nodeSize: _nodeCellSize,
        edgeColor: c.data,
        nodeBuilder: (context, id) {
          if (id == _rootId) {
            return _RootCell();
          }
          final node = nodesById[id]!;
          return _LineageNodeCell(
            node: node,
            kind: kindOf[id]!,
            code: codeOf[id]!,
            generation: generations[id]! - (generations.values.isEmpty
                ? 0
                : generations.values.reduce((a, b) => a > b ? a : b)),
            hasTurningPoint: turningPointIds.contains(id),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => NodeDetailSheet(node: node),
            ),
            onTurningPointTap: () => _showEvidence(evidenceByNodeId[id] ?? ''),
            onAccept: node.origin == model.NodeOrigin.sugerido ? () {} : null,
            onReject: node.origin == model.NodeOrigin.sugerido
                ? () => setState(() => _rejectedIds.add(id))
                : null,
          );
        },
      ),
    );
  }
}

class _RootCell extends StatelessWidget {
  const _RootCell();

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeShape(
          kind: NodeShapeKind.circle,
          size: 56,
          fill: c.id,
          border: c.id,
          child: Text('TÚ', style: HudText.operativa(c.bg, size: 14)),
        ),
      ],
    );
  }
}

class _LineageNodeCell extends StatelessWidget {
  const _LineageNodeCell({
    required this.node,
    required this.kind,
    required this.code,
    required this.generation,
    required this.hasTurningPoint,
    required this.onTap,
    required this.onTurningPointTap,
    this.onAccept,
    this.onReject,
  });

  final model.Node node;
  final _NodeKind kind;
  final String code;
  final int generation;
  final bool hasTurningPoint;
  final VoidCallback onTap;
  final VoidCallback onTurningPointTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final isSugerido = node.origin == model.NodeOrigin.sugerido;

    final NodeShapeKind shapeKind;
    final Color fill;
    switch (kind) {
      case _NodeKind.fuente:
        shapeKind = NodeShapeKind.hexagon;
        fill = c.unit;
      case _NodeKind.turningPoint:
        shapeKind = NodeShapeKind.diamond;
        fill = c.sys;
      case _NodeKind.sink:
        shapeKind = NodeShapeKind.doubleRing;
        fill = c.struct;
      case _NodeKind.concepto:
      case _NodeKind.root:
        shapeKind = NodeShapeKind.circle;
        fill = c.struct;
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('G${generation.toString()}', style: HudText.terminal(c.textDim, size: 9)),
          NodeShape(
            kind: shapeKind,
            size: 52,
            fill: fill,
            border: isSugerido ? c.text2 : fill,
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
          if (hasTurningPoint || onAccept != null || onReject != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasTurningPoint)
                  TurningPointBadge(onTap: onTurningPointTap),
                if (onAccept != null)
                  _HitTarget(
                    onTap: onAccept!,
                    child: Icon(Icons.check, size: 14, color: c.signal),
                  ),
                if (onReject != null)
                  _HitTarget(
                    onTap: onReject!,
                    child: Icon(Icons.close, size: 14, color: c.deny),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Wraps a small icon control with the 28x28pt minimum tap target
/// (accessibility.md § Mobility) without inflating its visible size.
class _HitTarget extends StatelessWidget {
  const _HitTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 28, height: 28, child: Center(child: child)),
    );
  }
}

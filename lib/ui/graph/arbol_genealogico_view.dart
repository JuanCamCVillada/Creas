// lib/ui/graph/arbol_genealogico_view.dart
import 'package:flutter/material.dart';

import '../../models/creative_graph.dart';
import '../../models/lineage_edge.dart';
import '../../models/node.dart' as model;
import '../theme/hud_alerts.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import 'canvas/graph_canvas.dart';
import 'canvas/graph_legend.dart';
import 'canvas/lineage_layout.dart';
import 'canvas/node_cell.dart';
import 'canvas/node_shapes.dart';
import 'node_detail_sheet.dart';
import 'node_icons.dart';

const _rootId = 'root-tu';
const _nodeCellSize = Size(150, 156);
const _columnSpacing = 210.0;
const _rowSpacing = 150.0;

enum _NodeKind { fuente, turningPoint, sink, concepto }

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

    final maxGeneration = generations.values.isEmpty
        ? 0
        : generations.values.reduce((a, b) => a > b ? a : b);

    // First incoming verified-lineage edge per target, used to trace one
    // upstream path back to a source for the detail sheet's "LINAJE"
    // breadcrumb. Deterministic (first match in edge order); the graph is
    // acyclic (graph_verifier.dart), so walking parents always terminates.
    final firstParentEdge = <String, LineageEdge>{};
    for (final edge in graph.edges) {
      firstParentEdge.putIfAbsent(edge.target, () => edge);
    }
    List<String> linajeFor(String id) {
      final chain = <String>[];
      var current = id;
      while (true) {
        final node = nodesById[current];
        if (node != null) chain.add('${codeOf[current]} ${node.label}');
        final parent = firstParentEdge[current];
        if (parent == null || !nodesById.containsKey(parent.source)) break;
        current = parent.source;
      }
      return chain.reversed.toList();
    }

    final lowConfidenceFuentes = visibleNodes
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
              final kind = kindOf[id]!;

              final NodeShapeKind shapeKind;
              final Color fill;
              final String kindLabel;
              final String glyph;
              switch (kind) {
                case _NodeKind.fuente:
                  shapeKind = NodeShapeKind.hexagon;
                  fill = c.unit;
                  kindLabel = 'FUENTE';
                  glyph = '源';
                case _NodeKind.turningPoint:
                  shapeKind = NodeShapeKind.diamond;
                  fill = c.sys;
                  kindLabel = 'PUNTO DE INFLEXIÓN';
                  glyph = '転機';
                case _NodeKind.sink:
                  shapeKind = NodeShapeKind.doubleRing;
                  fill = c.struct;
                  kindLabel = 'SÍNTESIS';
                  glyph = '合';
                case _NodeKind.concepto:
                  shapeKind = NodeShapeKind.circle;
                  fill = c.struct;
                  kindLabel = 'CONCEPTO';
                  glyph = '概';
              }

              final incoming = graph.edges.where((e) => e.target == id);
              final incomingFuentes = incoming
                  .where((e) => nodesById[e.source]?.type == model.NodeType.fuente)
                  .length;
              final incomingConceptos = incoming
                  .where((e) => nodesById[e.source]?.type == model.NodeType.concepto)
                  .length;
              final outgoing = graph.edges.where((e) => e.source == id).length;

              return GraphNodeCell(
                label: node.label,
                cluster: node.cluster,
                code: codeOf[id]!,
                shapeKind: shapeKind,
                fill: fill,
                icon: iconForNode(node),
                isSugerido: node.origin == model.NodeOrigin.sugerido,
                generationLabel: 'G${generations[id]! - maxGeneration}',
                hasTurningPoint: turningPointIds.contains(id),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => NodeDetailSheet(
                    node: node,
                    code: codeOf[id],
                    kindLabel: kindLabel,
                    glyph: glyph,
                    linaje: linajeFor(id),
                    turningPoint: kind == _NodeKind.turningPoint
                        ? graph.turningPoints.firstWhere((tp) => tp.nodeId == id)
                        : null,
                    stats: [
                      NodeStat('GENERACIÓN', 'G${generations[id]! - maxGeneration}'),
                      NodeStat('ASCENDENCIA', '$incomingConceptos C · $incomingFuentes F'),
                      NodeStat('DESCENDENCIA', '$outgoing nodos'),
                      NodeStat('PESO', node.confidence?.toStringAsFixed(2) ?? '—'),
                    ],
                  ),
                ),
                onTurningPointTap: () => _showEvidence(evidenceByNodeId[id] ?? ''),
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
          Positioned(
            left: 12,
            bottom: 12,
            child: IgnorePointer(
              child: GraphLegend(
                shapes: [
                  GraphLegendShape(kind: NodeShapeKind.hexagon, label: 'FUENTE', color: c.unit),
                  GraphLegendShape(kind: NodeShapeKind.circle, label: 'CONCEPTO', color: c.struct),
                  GraphLegendShape(
                      kind: NodeShapeKind.diamond, label: 'INFLEXIÓN', color: c.sys),
                  GraphLegendShape(
                      kind: NodeShapeKind.doubleRing, label: 'SÍNTESIS', color: c.struct),
                ],
                lines: [
                  GraphLegendLine(label: 'LINAJE VERIFICADO', dashed: false, color: c.data),
                  GraphLegendLine(
                      label: 'REFERENTE / INFLUENCIA DÉBIL', dashed: true, color: c.data),
                ],
              ),
            ),
          ),
        ],
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

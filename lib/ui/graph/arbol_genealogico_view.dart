// lib/ui/graph/arbol_genealogico_view.dart
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import '../theme/hud_tokens.dart';
import '../theme/hud_widgets.dart';
import 'node_detail_sheet.dart';
import 'node_icons.dart';
import 'turning_point_badge.dart';

const _rootId = 'root-tu';

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

    final graphViewGraph = Graph();
    graphViewGraph.addNode(Node.Id(_rootId));

    for (final node in visibleNodes.where((n) => n.level == 1)) {
      graphViewGraph.addEdge(Node.Id(_rootId), Node.Id(node.id));
    }
    for (final node in visibleNodes.where((n) => n.level == 2)) {
      final parentId = node.referenteOf;
      if (parentId != null && nodesById.containsKey(parentId)) {
        graphViewGraph.addEdge(Node.Id(parentId), Node.Id(node.id));
      }
    }
    for (final edge in graph.edges) {
      if (nodesById.containsKey(edge.source) && nodesById.containsKey(edge.target)) {
        graphViewGraph.addEdge(Node.Id(edge.source), Node.Id(edge.target));
      }
    }

    final rootHasEdge = graphViewGraph.edges
        .any((e) => e.source.key!.value == _rootId);
    if (!rootHasEdge) {
      final nodesWithIncomingEdge = graphViewGraph.edges
          .map((e) => e.destination.key!.value as String)
          .toSet();
      final connectedIds = <String>{};
      for (final e in graphViewGraph.edges) {
        connectedIds.add(e.source.key!.value as String);
        connectedIds.add(e.destination.key!.value as String);
      }
      connectedIds.remove(_rootId);
      final entryPoints =
          connectedIds.where((id) => !nodesWithIncomingEdge.contains(id));
      for (final id in entryPoints) {
        graphViewGraph.addEdge(Node.Id(_rootId), Node.Id(id));
      }
    }

    final configuration = SugiyamaConfiguration()
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
      ..nodeSeparation = 24
      ..levelSeparation = 48;

    return Container(
      color: c.bg,
      child: GraphView.builder(
        graph: graphViewGraph,
        algorithm: SugiyamaAlgorithm(configuration),
        builder: (node) {
          final id = node.key!.value as String;
          if (id == _rootId) {
            return const _TreeChip(label: 'TÚ', isRoot: true);
          }
          final modelNode = nodesById[id]!;
          return _TreeChip(
            label: modelNode.label,
            icon: iconForNode(modelNode),
            isSugerido: modelNode.origin == model.NodeOrigin.sugerido,
            hasTurningPoint: turningPointIds.contains(id),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => NodeDetailSheet(node: modelNode),
            ),
            onTurningPointTap: () => _showEvidence(evidenceByNodeId[id]!),
            onAccept: modelNode.origin == model.NodeOrigin.sugerido
                ? () {} // already visible; accepting just dismisses the prompt
                : null,
            onReject: modelNode.origin == model.NodeOrigin.sugerido
                ? () => setState(() => _rejectedIds.add(id))
                : null,
          );
        },
      ),
    );
  }
}

class _TreeChip extends StatelessWidget {
  const _TreeChip({
    required this.label,
    this.icon,
    this.isRoot = false,
    this.isSugerido = false,
    this.hasTurningPoint = false,
    this.onTap,
    this.onTurningPointTap,
    this.onAccept,
    this.onReject,
  });

  final String label;
  final IconData? icon;
  final bool isRoot;
  final bool isSugerido;
  final bool hasTurningPoint;
  final VoidCallback? onTap;
  final VoidCallback? onTurningPointTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return GestureDetector(
      onTap: onTap,
      child: HudChamferedBox(
        fill: isRoot ? c.id : c.struct,
        borderColor: isSugerido ? c.text2 : null,
        borderWidth: 1,
        chamfer: 6,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: c.text),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(color: isRoot ? c.bg : c.text, fontSize: 12),
            ),
            if (hasTurningPoint) ...[
              const SizedBox(width: 4),
              TurningPointBadge(onTap: onTurningPointTap ?? () {}),
            ],
            if (onAccept != null) ...[
              const SizedBox(width: 2),
              _HitTarget(
                onTap: onAccept!,
                child: Icon(Icons.check, size: 14, color: c.signal),
              ),
            ],
            if (onReject != null) ...[
              const SizedBox(width: 2),
              _HitTarget(
                onTap: onReject!,
                child: Icon(Icons.close, size: 14, color: c.deny),
              ),
            ],
          ],
        ),
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

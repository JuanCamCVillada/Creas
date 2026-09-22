// lib/ui/graph/arbol_genealogico_view.dart
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import 'node_detail_sheet.dart';
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
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Punto de inflexión'),
        content: Text(evidence),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return GraphView.builder(
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
    );
  }
}

class _TreeChip extends StatelessWidget {
  const _TreeChip({
    required this.label,
    this.isRoot = false,
    this.isSugerido = false,
    this.hasTurningPoint = false,
    this.onTap,
    this.onTurningPointTap,
    this.onAccept,
    this.onReject,
  });

  final String label;
  final bool isRoot;
  final bool isSugerido;
  final bool hasTurningPoint;
  final VoidCallback? onTap;
  final VoidCallback? onTurningPointTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isRoot ? Colors.black87 : Colors.blueGrey.shade700,
          borderRadius: BorderRadius.circular(8),
          border: isSugerido
              ? Border.all(color: Colors.white70, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
            if (hasTurningPoint) ...[
              const SizedBox(width: 4),
              TurningPointBadge(onTap: onTurningPointTap ?? () {}),
            ],
            if (onAccept != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onAccept,
                child: const Icon(Icons.check, size: 14, color: Colors.greenAccent),
              ),
            ],
            if (onReject != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onReject,
                child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

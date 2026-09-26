// lib/ui/graph/jardin_digital_view.dart
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import '../theme/hud_tokens.dart';
import '../theme/hud_widgets.dart';
import 'node_detail_sheet.dart';
import 'node_icons.dart';

class JardinDigitalView extends StatelessWidget {
  const JardinDigitalView({super.key, required this.graph});

  final CreativeGraph graph;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    // Guard against graphview crash on 0 or 1-node graphs
    if (graph.nodes.isEmpty) {
      return Container(
        color: c.bg,
        child: Center(
          child: Text('El jardín está vacío.', style: TextStyle(color: c.textDim)),
        ),
      );
    }
    if (graph.nodes.length == 1) {
      final onlyNode = graph.nodes.first;
      return Container(
        color: c.bg,
        child: Center(
          child: _NodeChip(
            node: onlyNode,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => NodeDetailSheet(node: onlyNode),
            ),
          ),
        ),
      );
    }

    final nodesById = {for (final node in graph.nodes) node.id: node};
    final graphViewGraph = Graph();

    for (final node in graph.nodes) {
      graphViewGraph.addNode(Node.Id(node.id));
    }

    // Track which nodes have edges
    final nodesWithEdges = <String>{};
    for (final edge in graph.affinityEdges) {
      nodesWithEdges.add(edge.source);
      nodesWithEdges.add(edge.target);
      graphViewGraph.addEdge(Node.Id(edge.source), Node.Id(edge.target));
    }

    // Add self-loops for isolated nodes to ensure the layout algorithm positions them
    for (final node in graph.nodes) {
      if (!nodesWithEdges.contains(node.id)) {
        graphViewGraph.addEdge(Node.Id(node.id), Node.Id(node.id));
      }
    }

    final algorithm = FruchtermanReingoldAlgorithm(FruchtermanReingoldConfiguration());

    return Container(
      color: c.bg,
      child: GraphView.builder(
        graph: graphViewGraph,
        algorithm: algorithm,
        builder: (node) {
          final id = node.key!.value as String;
          final modelNode = nodesById[id]!;
          return _NodeChip(
            node: modelNode,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => NodeDetailSheet(node: modelNode),
            ),
          );
        },
      ),
    );
  }
}

class _NodeChip extends StatelessWidget {
  const _NodeChip({required this.node, required this.onTap});

  final model.Node node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    // Every cluster reads on the same --struct fill (verified ~7.4:1 with
    // --paper text) — cluster identity comes from the node's icon, not from
    // hue, so no chip can fall below the accessible-contrast floor the way
    // the old 8-color hashed palette did.
    return GestureDetector(
      onTap: onTap,
      child: HudChamferedBox(
        fill: c.struct,
        chamfer: 6,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconForNode(node), size: 14, color: c.text),
            const SizedBox(width: 4),
            Text(
              node.label,
              style: TextStyle(color: c.text, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

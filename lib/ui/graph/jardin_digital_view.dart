// lib/ui/graph/jardin_digital_view.dart
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import 'node_detail_sheet.dart';

class JardinDigitalView extends StatelessWidget {
  const JardinDigitalView({super.key, required this.graph});

  final CreativeGraph graph;

  static const _clusterPalette = [
    Colors.teal,
    Colors.deepOrange,
    Colors.indigo,
    Colors.pink,
    Colors.green,
    Colors.amber,
    Colors.purple,
    Colors.cyan,
  ];

  Color _colorForCluster(String cluster) {
    final index = cluster.hashCode.abs() % _clusterPalette.length;
    return _clusterPalette[index];
  }

  @override
  Widget build(BuildContext context) {
    // Guard against graphview crash on 0 or 1-node graphs
    if (graph.nodes.isEmpty) {
      return const Center(child: Text('El jardín está vacío.'));
    }
    if (graph.nodes.length == 1) {
      final onlyNode = graph.nodes.first;
      return Center(
        child: _NodeChip(
          node: onlyNode,
          color: _colorForCluster(onlyNode.cluster),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => NodeDetailSheet(node: onlyNode),
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

    return GraphView.builder(
      graph: graphViewGraph,
      algorithm: algorithm,
      builder: (node) {
        final id = node.key!.value as String;
        final modelNode = nodesById[id]!;
        return _NodeChip(
          node: modelNode,
          color: _colorForCluster(modelNode.cluster),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => NodeDetailSheet(node: modelNode),
          ),
        );
      },
    );
  }
}

class _NodeChip extends StatelessWidget {
  const _NodeChip({required this.node, required this.color, required this.onTap});

  final model.Node node;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          node.label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

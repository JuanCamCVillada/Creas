import 'node.dart';
import 'lineage_edge.dart';
import 'affinity_edge.dart';
import 'turning_point.dart';

class CreativeGraph {
  const CreativeGraph({
    required this.nodes,
    required this.edges,
    required this.affinityEdges,
    required this.turningPoints,
    required this.followupQuestions,
  });

  final List<Node> nodes;
  final List<LineageEdge> edges;
  final List<AffinityEdge> affinityEdges;
  final List<TurningPoint> turningPoints;
  final List<String> followupQuestions;

  CreativeGraph copyWith({List<TurningPoint>? turningPoints}) {
    return CreativeGraph(
      nodes: nodes,
      edges: edges,
      affinityEdges: affinityEdges,
      turningPoints: turningPoints ?? this.turningPoints,
      followupQuestions: followupQuestions,
    );
  }

  factory CreativeGraph.fromJson(Map<String, dynamic> json) {
    return CreativeGraph(
      nodes: (json['nodes'] as List)
          .map((e) => Node.fromJson(e as Map<String, dynamic>))
          .toList(),
      edges: (json['edges'] as List)
          .map((e) => LineageEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
      affinityEdges: (json['affinity_edges'] as List)
          .map((e) => AffinityEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
      turningPoints: (json['turning_points'] as List)
          .map((e) => TurningPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      followupQuestions: (json['followup_questions'] as List)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'affinity_edges': affinityEdges.map((e) => e.toJson()).toList(),
        'turning_points': turningPoints.map((t) => t.toJson()).toList(),
        'followup_questions': followupQuestions,
      };
}

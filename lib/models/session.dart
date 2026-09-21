import 'creative_graph.dart';

class GraphSession {
  const GraphSession({
    required this.id,
    required this.rawInput,
    required this.graph,
    required this.createdAt,
  });

  final String id;
  final String rawInput;
  final CreativeGraph graph;
  final DateTime createdAt;

  factory GraphSession.fromJson(Map<String, dynamic> json) {
    return GraphSession(
      id: json['id'] as String,
      rawInput: json['raw_input'] as String,
      graph: CreativeGraph.fromJson(json['graph'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'raw_input': rawInput,
        'graph': graph.toJson(),
        'created_at': createdAt.toIso8601String(),
      };
}

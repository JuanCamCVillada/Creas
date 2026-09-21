class AffinityEdge {
  const AffinityEdge({
    required this.source,
    required this.target,
    required this.weight,
  });

  final String source;
  final String target;
  final double weight;

  factory AffinityEdge.fromJson(Map<String, dynamic> json) => AffinityEdge(
        source: json['source'] as String,
        target: json['target'] as String,
        weight: (json['weight'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target,
        'weight': weight,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AffinityEdge &&
          source == other.source &&
          target == other.target &&
          weight == other.weight;

  @override
  int get hashCode => Object.hash(source, target, weight);
}

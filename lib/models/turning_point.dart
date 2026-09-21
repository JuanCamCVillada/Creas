class TurningPoint {
  const TurningPoint({
    required this.nodeId,
    required this.evidence,
    this.convergence = false,
    this.directionChange = false,
  });

  final String nodeId;
  final String evidence;
  final bool convergence;
  final bool directionChange;

  bool get isVerified => convergence && directionChange;

  factory TurningPoint.fromCandidateJson(Map<String, dynamic> json) {
    return TurningPoint(
      nodeId: json['node_id'] as String,
      evidence: json['evidence'] as String,
    );
  }

  factory TurningPoint.fromJson(Map<String, dynamic> json) {
    return TurningPoint(
      nodeId: json['node_id'] as String,
      evidence: json['evidence'] as String,
      convergence: json['convergence'] as bool? ?? false,
      directionChange: json['direction_change'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'node_id': nodeId,
        'evidence': evidence,
        'convergence': convergence,
        'direction_change': directionChange,
      };

  TurningPoint copyWith({bool? convergence, bool? directionChange}) {
    return TurningPoint(
      nodeId: nodeId,
      evidence: evidence,
      convergence: convergence ?? this.convergence,
      directionChange: directionChange ?? this.directionChange,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TurningPoint &&
          nodeId == other.nodeId &&
          evidence == other.evidence &&
          convergence == other.convergence &&
          directionChange == other.directionChange;

  @override
  int get hashCode =>
      Object.hash(nodeId, evidence, convergence, directionChange);
}

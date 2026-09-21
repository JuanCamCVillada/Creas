enum NodeType { fuente, concepto }

enum NodeOrigin { usuario, sugerido }

class Node {
  const Node({
    required this.id,
    required this.type,
    required this.label,
    required this.description,
    required this.cluster,
    required this.origin,
    this.confidence,
    this.timestamp,
    this.sequence,
    this.level,
    this.referenteOf,
  });

  final String id;
  final NodeType type;
  final String label;
  final String description;
  final String cluster;
  final NodeOrigin origin;
  final double? confidence;
  final String? timestamp;
  final int? sequence;
  final int? level;
  final String? referenteOf;

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] as String,
      type: _parseType(json['type'] as String),
      label: json['label'] as String,
      description: json['description'] as String,
      cluster: json['cluster'] as String,
      origin: _parseOrigin(json['origin'] as String),
      confidence: (json['confidence'] as num?)?.toDouble(),
      timestamp: json['timestamp'] as String?,
      sequence: (json['sequence'] as num?)?.toInt(),
      level: (json['level'] as num?)?.toInt(),
      referenteOf: json['referente_of'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == NodeType.fuente ? 'fuente' : 'concepto',
        'label': label,
        'description': description,
        'cluster': cluster,
        'origin': origin == NodeOrigin.usuario ? 'usuario' : 'sugerido',
        if (confidence != null) 'confidence': confidence,
        if (timestamp != null) 'timestamp': timestamp,
        if (sequence != null) 'sequence': sequence,
        if (level != null) 'level': level,
        if (referenteOf != null) 'referente_of': referenteOf,
      };

  static NodeType _parseType(String raw) {
    switch (raw) {
      case 'fuente':
        return NodeType.fuente;
      case 'concepto':
        return NodeType.concepto;
      default:
        throw FormatException('tipo de nodo desconocido: $raw');
    }
  }

  static NodeOrigin _parseOrigin(String raw) {
    switch (raw) {
      case 'usuario':
        return NodeOrigin.usuario;
      case 'sugerido':
        return NodeOrigin.sugerido;
      default:
        throw FormatException('origen de nodo desconocido: $raw');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node &&
          id == other.id &&
          type == other.type &&
          label == other.label &&
          description == other.description &&
          cluster == other.cluster &&
          origin == other.origin &&
          confidence == other.confidence &&
          timestamp == other.timestamp &&
          sequence == other.sequence &&
          level == other.level &&
          referenteOf == other.referenteOf;

  @override
  int get hashCode => Object.hash(id, type, label, description, cluster,
      origin, confidence, timestamp, sequence, level, referenteOf);
}

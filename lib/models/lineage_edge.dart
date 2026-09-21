enum LineageRelation { desencadena, derivaDe, inspira, transformaEn }

class LineageEdge {
  const LineageEdge({
    required this.id,
    required this.source,
    required this.target,
    required this.relation,
  });

  final String id;
  final String source;
  final String target;
  final LineageRelation relation;

  factory LineageEdge.fromJson(Map<String, dynamic> json) {
    return LineageEdge(
      id: json['id'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      relation: _parseRelation(json['relation'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'target': target,
        'relation': _relationToJson(relation),
      };

  static LineageRelation _parseRelation(String raw) {
    switch (raw) {
      case 'desencadena':
        return LineageRelation.desencadena;
      case 'deriva_de':
        return LineageRelation.derivaDe;
      case 'inspira':
        return LineageRelation.inspira;
      case 'transforma_en':
        return LineageRelation.transformaEn;
      default:
        throw FormatException('relación de linaje desconocida: $raw');
    }
  }

  static String _relationToJson(LineageRelation relation) {
    switch (relation) {
      case LineageRelation.desencadena:
        return 'desencadena';
      case LineageRelation.derivaDe:
        return 'deriva_de';
      case LineageRelation.inspira:
        return 'inspira';
      case LineageRelation.transformaEn:
        return 'transforma_en';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineageEdge &&
          id == other.id &&
          source == other.source &&
          target == other.target &&
          relation == other.relation;

  @override
  int get hashCode => Object.hash(id, source, target, relation);
}

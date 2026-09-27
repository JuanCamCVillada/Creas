// lib/ui/graph/graph_status.dart
import '../../models/node.dart';
import '../theme/hud_tokens.dart';

/// Fuente nodes whose confidence is low enough to warrant a review — the
/// one real, data-driven "precaución" signal both graph views share.
/// Shared here so the two views can't silently diverge on the threshold.
List<Node> lowConfidenceFuentes(List<Node> nodes) => nodes
    .where((n) => n.type == NodeType.fuente && n.confidence != null && n.confidence! < 0.5)
    .toList();

HudStatus statusForLowConfidence(List<Node> lowConfidence) =>
    lowConfidence.isEmpty ? HudStatus.nominal : HudStatus.precaucion;

/// A banner title naming every affected fuente, not just the first one —
/// showing only `lowConfidence.first` silently hid the rest whenever more
/// than one fuente needed review.
String lowConfidenceBannerTitle(List<Node> lowConfidence, Map<String, String> codeOf) {
  if (lowConfidence.length == 1) {
    final n = lowConfidence.first;
    return 'FUENTE ${codeOf[n.id] ?? n.id} CON CONFIANZA BAJA '
        '(${n.confidence!.toStringAsFixed(2)})';
  }
  final codes = lowConfidence.map((n) => codeOf[n.id] ?? n.id).join(', ');
  return '${lowConfidence.length} FUENTES CON CONFIANZA BAJA ($codes)';
}

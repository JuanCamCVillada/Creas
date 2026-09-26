// lib/ui/graph/node_detail_sheet.dart
import 'package:flutter/material.dart';

import '../../models/node.dart';
import '../../models/turning_point.dart';
import '../theme/hud_alerts.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import '../theme/hud_widgets.dart';

/// A label→value pair shown in the sheet's stat grid, e.g. ("GENERACIÓN",
/// "G-2"). Callers compute these from the graph they already hold (edge
/// counts, generation layering, affinity degree) — the sheet itself has no
/// access to the graph, so it never fabricates a number it can't back.
class NodeStat {
  const NodeStat(this.label, this.value);
  final String label;
  final String value;
}

class NodeDetailSheet extends StatelessWidget {
  const NodeDetailSheet({
    super.key,
    required this.node,
    this.code,
    this.kindLabel,
    this.glyph,
    this.stats = const [],
    this.linaje = const [],
    this.turningPoint,
  });

  final Node node;

  /// Short id badge, e.g. "F-01" — the same code shown on the node cell.
  final String? code;

  /// e.g. "FUENTE", "CONCEPTO", "PUNTO DE INFLEXIÓN", "SÍNTESIS".
  final String? kindLabel;

  /// A single CJK glyph decorating [kindLabel], matching the app's other
  /// tactical iconography (転機 for a turning point, 合 for a synthesis
  /// sink, …). Purely typographic — never a substitute for [kindLabel].
  final String? glyph;

  final List<NodeStat> stats;

  /// The chain of codes leading from a source down to this node, e.g.
  /// ["F-01 Clepsidra", "C-01 Flujo visible", "INF-01 Ruptura"] — omitted
  /// (empty) for graphs with no directed lineage, like Jardín Digital.
  final List<String> linaje;

  /// When this node is a verified turning point, its real convergence /
  /// direction-change evidence (graph_verifier.dart already computed and
  /// filtered these — no fabricated "critic votes", just the two signals
  /// the app actually derives).
  final TurningPoint? turningPoint;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final lowConfidence = node.confidence != null && node.confidence! < 0.5;
    return Material(
      color: c.panel,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  color: c.grid,
                ),
              ),
              if (code != null || kindLabel != null) ...[
                Row(
                  children: [
                    if (code != null) HudIdBadge(label: code!),
                    if (code != null && kindLabel != null) const SizedBox(width: 10),
                    if (kindLabel != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (glyph != null) ...[
                            Text(glyph!, style: HudText.operativa(c.data, size: 16)),
                            const SizedBox(width: 6),
                          ],
                          Text(kindLabel!, style: HudText.operativa(c.text2, size: 12)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Text(node.label, style: HudText.operativa(c.text, size: 20)),
              const SizedBox(height: 8),
              Text(node.description, style: TextStyle(color: c.text2)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _tag(c, node.cluster, c.data),
                  _tag(
                    c,
                    node.origin == NodeOrigin.usuario ? 'usuario' : 'sugerido',
                    node.origin == NodeOrigin.usuario ? c.signal : c.id,
                  ),
                  if (node.confidence != null)
                    _tag(c, 'confianza ${(node.confidence! * 100).round()}%',
                        lowConfidence ? c.caution : c.ok),
                ],
              ),
              if (lowConfidence) ...[
                const SizedBox(height: 14),
                HudHazardBanner(
                  status: HudStatus.precaucion,
                  glyph: '注意',
                  title: '${code ?? 'FUENTE'} CON CONFIANZA BAJA '
                      '(${node.confidence!.toStringAsFixed(2)})',
                  subtitle: 'Revisar antes de derivar conceptos desde aquí.',
                ),
              ],
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    for (final stat in stats) HudReadout(label: stat.label, value: stat.value),
                  ],
                ),
              ],
              if (linaje.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('LINAJE', style: HudText.operativa(c.text2, size: 12)),
                const SizedBox(height: 6),
                Text(linaje.join('  ▶  '), style: HudText.terminal(c.data, size: 12)),
              ],
              if (turningPoint != null) ...[
                const SizedBox(height: 16),
                Text('VERIFICACIÓN DEL PUNTO DE INFLEXIÓN',
                    style: HudText.operativa(c.text2, size: 12)),
                const SizedBox(height: 8),
                _verificationRow(c, 'CONVERGENCIA · MÚLTIPLES FUENTES',
                    turningPoint!.convergence),
                const SizedBox(height: 6),
                _verificationRow(c, 'CAMBIO DE DIRECCIÓN', turningPoint!.directionChange),
                const SizedBox(height: 10),
                HudChamferedBox(
                  fill: c.sys.withValues(alpha: 0.12),
                  borderColor: c.sys,
                  borderWidth: 1.5,
                  chamfer: 4,
                  child: Text('RESULTADO: VERIFICADO', style: HudText.operativa(c.sys, size: 12)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _verificationRow(HudColors c, String label, bool passed) {
    final accent = passed ? c.sys : c.textDim;
    return Row(
      children: [
        Expanded(child: Text(label, style: HudText.terminal(c.text2, size: 12))),
        HudChamferedBox(
          fill: Colors.transparent,
          borderColor: accent,
          borderWidth: 1,
          chamfer: 4,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(passed ? '承認' : '—', style: HudText.operativa(accent, size: 11)),
        ),
      ],
    );
  }

  Widget _tag(HudColors c, String label, Color accent) {
    return HudChamferedBox(
      fill: Colors.transparent,
      borderColor: accent,
      borderWidth: 1,
      chamfer: 4,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(label, style: HudText.terminal(accent, size: 11)),
    );
  }
}

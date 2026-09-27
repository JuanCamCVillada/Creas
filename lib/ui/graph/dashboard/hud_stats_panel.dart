// lib/ui/graph/dashboard/hud_stats_panel.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/session.dart';
import '../../theme/hud_tokens.dart';
import '../../theme/hud_text.dart';
import '../../theme/hud_widgets.dart';
import '../canvas/lineage_layout.dart';

/// The session's own devlog, then a stat grid computed straight from the
/// graph (no invented numbers — every figure here is a real count) and a
/// real export action. Used two ways: as the wide-layout's persistent left
/// column (fixed [width]), and as the content of a mobile "INFO" modal
/// (width left null so it fills whatever sheet it's shown in).
class HudStatsPanel extends StatefulWidget {
  const HudStatsPanel({super.key, required this.session, this.width = 280});

  final GraphSession session;
  final double? width;

  @override
  State<HudStatsPanel> createState() => _HudStatsPanelState();
}

class _HudStatsPanelState extends State<HudStatsPanel> {
  bool _copied = false;

  Future<void> _exportGraph() async {
    final json = const JsonEncoder.withIndent('  ').convert(widget.session.graph.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final graph = widget.session.graph;
    // Same longest-path layering the Árbol Genealógico canvas uses for its
    // own generation columns, applied here to just the verified lineage
    // edges — a real derivation-depth count, not an estimate.
    final generationDepths = computeGenerations(
      nodeIds: graph.nodes.map((n) => n.id).toList(),
      edges: [for (final e in graph.edges) (e.source, e.target)],
    );
    final generations = generationDepths.values.isEmpty
        ? (graph.nodes.isEmpty ? 0 : 1)
        : generationDepths.values.reduce((a, b) => a > b ? a : b) + 1;

    return Container(
      width: widget.width,
      color: c.panel,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SUBJECT:', style: HudText.operativa(c.textDim, size: 11)),
            const SizedBox(height: 8),
            Text('系譜', style: HudText.operativa(c.data.withValues(alpha: 0.6), size: 40)),
            const SizedBox(height: 4),
            Text('SÍNTESIS CREATIVA', style: HudText.operativa(c.text, size: 15)),
            const SizedBox(height: 16),
            Text('ENTRADA DEL OPERADOR', style: HudText.operativa(c.textDim, size: 10)),
            const SizedBox(height: 6),
            HudChamferedBox(
              fill: Colors.transparent,
              borderColor: c.grid,
              borderWidth: 1,
              chamfer: 6,
              child: Text(
                widget.session.rawInput,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: HudText.terminal(c.text2, size: 12),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: HudReadout(label: 'NODOS', value: '${graph.nodes.length}')),
                Expanded(
                    child: HudReadout(label: 'ARISTAS', value: '${graph.edges.length}')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: HudReadout(label: 'GENERACIONES', value: '$generations')),
                Expanded(
                  child: HudReadout(
                    label: 'INFLEXIONES',
                    value: '${graph.turningPoints.where((tp) => tp.isVerified).length}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            InkWell(
              onTap: _exportGraph,
              child: HudChamferedBox(
                fill: Colors.transparent,
                borderColor: _copied ? c.signal : c.sys,
                borderWidth: 1.5,
                child: Row(
                  children: [
                    Text('▶', style: TextStyle(color: _copied ? c.signal : c.sys, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _copied ? 'COPIADO' : 'EXPORTAR JSON',
                        overflow: TextOverflow.ellipsis,
                        style: HudText.operativa(_copied ? c.signal : c.sys, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

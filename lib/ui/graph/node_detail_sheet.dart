// lib/ui/graph/node_detail_sheet.dart
import 'package:flutter/material.dart';

import '../../models/node.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import '../theme/hud_widgets.dart';

class NodeDetailSheet extends StatelessWidget {
  const NodeDetailSheet({super.key, required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Material(
      color: c.panel,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grabber
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  color: c.grid,
                ),
              ),
              Text(node.label, style: HudText.operativa(c.text, size: 20)),
              const SizedBox(height: 8),
              Text(node.description, style: TextStyle(color: c.text2)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _tag(c, node.cluster, c.data),
                  _tag(
                    c,
                    node.origin == NodeOrigin.usuario ? 'usuario' : 'sugerido',
                    node.origin == NodeOrigin.usuario ? c.signal : c.id,
                  ),
                  if (node.confidence != null)
                    _tag(c, 'confianza ${(node.confidence! * 100).round()}%', c.caution),
                ],
              ),
            ],
          ),
        ),
      ),
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

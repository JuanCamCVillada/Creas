// lib/ui/graph/dashboard/hud_detail_panel.dart
import 'package:flutter/material.dart';

import '../../theme/hud_tokens.dart';
import '../../theme/hud_text.dart';

/// The wide-layout right column: whatever [NodeDetailSheet] the last
/// tapped node built, rendered in place instead of as a modal — or a
/// placeholder when nothing has been selected yet.
class HudDetailPanel extends StatelessWidget {
  const HudDetailPanel({super.key, required this.detail});

  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Container(
      width: 320,
      color: c.panel,
      child: detail ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('◇', style: TextStyle(color: c.textDim, fontSize: 28)),
                  const SizedBox(height: 12),
                  Text(
                    'SELECCIONA UN NODO',
                    textAlign: TextAlign.center,
                    style: HudText.operativa(c.textDim, size: 12),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

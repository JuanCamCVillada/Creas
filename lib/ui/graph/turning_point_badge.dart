// lib/ui/graph/turning_point_badge.dart
import 'package:flutter/material.dart';

import '../theme/hud_tokens.dart';

class TurningPointBadge extends StatelessWidget {
  const TurningPointBadge({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: c.caution, shape: BoxShape.circle),
        child: Icon(Icons.auto_awesome, size: 14, color: c.bg),
      ),
    );
  }
}

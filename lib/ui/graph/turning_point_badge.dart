// lib/ui/graph/turning_point_badge.dart
import 'package:flutter/material.dart';

class TurningPointBadge extends StatelessWidget {
  const TurningPointBadge({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome, size: 14, color: Colors.black87),
      ),
    );
  }
}

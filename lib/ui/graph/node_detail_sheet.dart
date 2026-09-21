// lib/ui/graph/node_detail_sheet.dart
import 'package:flutter/material.dart';

import '../../models/node.dart';

class NodeDetailSheet extends StatelessWidget {
  const NodeDetailSheet({super.key, required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(node.description),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(node.cluster)),
                  Chip(
                    label: Text(
                      node.origin == NodeOrigin.usuario ? 'usuario' : 'sugerido',
                    ),
                  ),
                  if (node.confidence != null)
                    Chip(
                      label: Text(
                        'confianza ${(node.confidence! * 100).round()}%',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

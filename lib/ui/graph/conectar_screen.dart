// lib/ui/graph/conectar_screen.dart
import 'package:flutter/material.dart';

import '../../models/creative_graph.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_widgets.dart';
import 'arbol_genealogico_view.dart';

/// CONECTAR: Linaje y Jardín fusionados in one screen — the directed
/// lineage tree with Jardín Digital's affinity connections overlaid on
/// top, so a relation that never made it into the verified lineage but
/// still shows up as a strong affinity is visible in the same view.
class ConectarScreen extends StatelessWidget {
  const ConectarScreen({super.key, required this.graph});

  final CreativeGraph graph;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const HudIdBadge(label: 'Conectar · Linaje + Jardín'),
      ),
      body: ArbolGenealogicoView(graph: graph, showAffinity: true),
    );
  }
}

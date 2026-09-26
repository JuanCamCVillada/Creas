import 'package:flutter/material.dart';

import '../../models/session.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import '../theme/hud_widgets.dart';
import 'arbol_genealogico_view.dart';
import 'jardin_digital_view.dart';

class GraphViewScreen extends StatelessWidget {
  const GraphViewScreen({super.key, required this.session});

  final GraphSession session;

  static const _months = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
  ];

  String _shortDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final followupQuestions = session.graph.followupQuestions;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          title: HudIdBadge(label: 'Sesión · ${_shortDate(session.createdAt)}'),
          bottom: TabBar(
            indicatorColor: c.sys,
            labelColor: c.sys,
            unselectedLabelColor: c.textDim,
            labelStyle: HudText.operativa(c.sys, size: 13),
            unselectedLabelStyle: HudText.operativa(c.textDim, size: 13),
            tabs: const [
              Tab(text: '01 JARDÍN'),
              Tab(text: '02 LINAJE'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (followupQuestions.isNotEmpty)
              HudChamferedBox(
                fill: c.bg,
                borderColor: c.caution,
                borderWidth: 2,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: c.caution, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PRECAUCIÓN: datos insuficientes. ${followupQuestions.join(' ')}',
                        style: HudText.terminal(c.text2, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  JardinDigitalView(graph: session.graph),
                  ArbolGenealogicoView(graph: session.graph),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

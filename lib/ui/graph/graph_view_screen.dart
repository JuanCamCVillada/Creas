import 'package:flutter/material.dart';

import '../../models/session.dart';
import 'arbol_genealogico_view.dart';
import 'jardin_digital_view.dart';

class GraphViewScreen extends StatelessWidget {
  const GraphViewScreen({super.key, required this.session});

  final GraphSession session;

  @override
  Widget build(BuildContext context) {
    final followupQuestions = session.graph.followupQuestions;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Genealogía Creativa'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Jardín Digital'),
            Tab(text: 'Árbol Genealógico'),
          ]),
        ),
        body: Column(
          children: [
            if (followupQuestions.isNotEmpty)
              MaterialBanner(
                content: Text(
                  'Para construir el árbol, respóndenos: ${followupQuestions.join(' ')}',
                ),
                actions: const [SizedBox.shrink()],
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

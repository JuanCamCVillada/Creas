import 'package:flutter/material.dart';

import '../../models/session.dart';

class GraphViewScreen extends StatelessWidget {
  const GraphViewScreen({super.key, required this.session});

  final GraphSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(session.rawInput)),
      body: const Center(child: Text('TODO')),
    );
  }
}

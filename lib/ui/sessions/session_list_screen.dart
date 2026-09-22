import 'package:flutter/material.dart';

import '../../engine/graph_generator.dart';
import '../../models/session.dart';
import '../../storage/api_key_store.dart';
import '../../storage/session_store.dart';
import '../graph/graph_view_screen.dart';
import '../input/input_screen.dart';
import '../settings/api_key_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({
    super.key,
    required this.sessionStore,
    required this.apiKeyStore,
    required this.generator,
  });

  final SessionStore sessionStore;
  final ApiKeyStore apiKeyStore;
  final GraphGenerator generator;

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  List<GraphSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await widget.sessionStore.listSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  Future<void> _openNewSession() async {
    final session = await Navigator.of(context).push<GraphSession>(
      MaterialPageRoute(
        builder: (_) => InputScreen(
          generator: widget.generator,
          sessionStore: widget.sessionStore,
        ),
      ),
    );
    if (session != null) {
      setState(() => _sessions = [session, ..._sessions]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Genealogía Creativa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'Clave de API',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ApiKeyScreen(apiKeyStore: widget.apiKeyStore),
            )),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('Aún no tienes sesiones. Crea una nueva.'))
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final snippet = session.rawInput.length > 80
                        ? '${session.rawInput.substring(0, 80)}…'
                        : session.rawInput;
                    return ListTile(
                      title: Text(snippet),
                      subtitle: Text(session.createdAt.toLocal().toString()),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GraphViewScreen(session: session),
                      )),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewSession,
        icon: const Icon(Icons.add),
        label: const Text('Nueva sesión'),
      ),
    );
  }
}

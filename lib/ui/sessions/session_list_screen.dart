import 'package:flutter/material.dart';

import '../../engine/graph_generator.dart';
import '../../models/session.dart';
import '../../storage/api_key_store.dart';
import '../../storage/session_store.dart';
import '../graph/graph_view_screen.dart';
import '../input/input_screen.dart';
import '../settings/api_key_screen.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import '../theme/hud_widgets.dart';

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

  static const _months = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
  ];

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_months[local.month - 1]} ${local.year} · $hh:$mm';
  }

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
    final c = HudColors.consola;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const HudIdBadge(label: 'ARCHIVO-RAÍZ'),
        actions: [
          IconButton(
            icon: Icon(Icons.key, color: c.sys),
            tooltip: 'Credencial del sistema',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ApiKeyScreen(apiKeyStore: widget.apiKeyStore),
            )),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.sys))
          : _sessions.isEmpty
              ? Center(
                  child: Text(
                    'Aún no tienes sesiones. Inicia una operación.',
                    textAlign: TextAlign.center,
                    style: HudText.operativa(c.text2, size: 15, weight: FontWeight.w500),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final snippet = session.rawInput.length > 80
                        ? '${session.rawInput.substring(0, 80)}…'
                        : session.rawInput;
                    return InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GraphViewScreen(session: session),
                      )),
                      child: HudChamferedBox(
                        fill: c.panel,
                        borderColor: c.grid,
                        borderWidth: 1,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SESIÓN · ${_formatTimestamp(session.createdAt)}',
                              style: HudText.terminal(c.id, size: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(snippet, style: TextStyle(color: c.text, fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: HudButton(
        label: 'NUEVA OPERACIÓN',
        onPressed: _openNewSession,
      ),
    );
  }
}

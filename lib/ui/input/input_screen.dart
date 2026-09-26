import 'package:flutter/material.dart';

import '../../engine/graph_generator.dart';
import '../../storage/session_store.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import '../theme/hud_widgets.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({
    super.key,
    required this.generator,
    required this.sessionStore,
  });

  final GraphGenerator generator;
  final SessionStore sessionStore;

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.generator.generate(_controller.text);
      await widget.sessionStore.saveSession(session);
      if (mounted) Navigator.of(context).pop(session);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const HudIdBadge(label: 'Operación: síntesis')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              HudChamferedBox(
                fill: c.bg,
                borderColor: c.deny,
                borderWidth: 2,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: c.deny, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ALERTA: $_error',
                        style: HudText.terminal(c.text2, size: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _error = null),
                      child: Text('CERRAR', style: HudText.operativa(c.deny, size: 12)),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _generate,
                      child: Text('REINTENTAR', style: HudText.operativa(c.sys, size: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('ENTRADA:', style: HudText.operativa(c.text2, size: 12)),
            const SizedBox(height: 6),
            SizedBox(
              height: 220,
              child: HudChamferedBox(
                fill: c.panel,
                borderColor: c.text,
                borderWidth: 1.5,
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(color: c.text, fontSize: 14),
                    cursorColor: c.sys,
                    decoration: InputDecoration(
                      hintText: 'Pega tu devlog, retro o transcripción...',
                      hintStyle: TextStyle(color: c.textDim),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _loading
                ? const Center(child: HudSyncIndicator())
                : HudButton(label: 'GENERAR', onPressed: _generate),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

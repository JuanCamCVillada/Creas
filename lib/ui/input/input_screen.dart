import 'package:flutter/material.dart';

import '../../engine/graph_generator.dart';
import '../../storage/session_store.dart';
import '../theme/hud_alerts.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import '../theme/hud_widgets.dart';
import 'guided_input_flow.dart';

enum _InputMode { guiado, libre }

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
  // LIBRE (the plain text field) stays the default: it's the one path
  // that's always been tested and works with a screen reader or paste,
  // and GUIADO's whole value is opt-in structure, not a forced detour.
  _InputMode _mode = _InputMode.libre;
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

  Future<void> _generateFromGuided(String combinedText) async {
    _controller.text = combinedText;
    await _generate();
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
              HudHazardBanner(
                status: HudStatus.emergencia,
                glyph: '警報',
                title: 'ALERTA: $_error',
                actions: [
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
              const SizedBox(height: 16),
            ],
            HudSegmentedTabs(
              labels: const ['GUIADO', 'LIBRE'],
              selectedIndex: _mode.index,
              onSelected: _loading
                  ? (_) {}
                  : (i) => setState(() => _mode = _InputMode.values[i]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _mode == _InputMode.guiado
                  ? GuidedInputFlow(onComplete: _generateFromGuided, loading: _loading)
                  : _LibreInput(
                      controller: _controller,
                      loading: _loading,
                      onGenerate: _generate,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              'NOTA: la calidad del resultado depende del prompt ingresado '
              'y del problema descrito.',
              style: HudText.terminal(c.textDim, size: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibreInput extends StatelessWidget {
  const _LibreInput({
    required this.controller,
    required this.loading,
    required this.onGenerate,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ENTRADA:', style: HudText.operativa(c.text2, size: 12)),
        const SizedBox(height: 6),
        Expanded(
          child: HudChamferedBox(
            fill: c.panel,
            borderColor: c.text,
            borderWidth: 1.5,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: controller,
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
        loading
            ? const Center(child: HudSyncIndicator())
            : HudButton(label: 'GENERAR', onPressed: onGenerate),
      ],
    );
  }
}

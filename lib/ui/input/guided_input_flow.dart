// lib/ui/input/guided_input_flow.dart
import 'package:flutter/material.dart';

import '../theme/hud_text.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_widgets.dart';

class _GuidedQuestion {
  const _GuidedQuestion({required this.label, required this.hint});
  final String label;
  final String hint;
}

const _questions = [
  _GuidedQuestion(
    label: '¿QUÉ PROBLEMA U OBJETIVO ESTABAS RESOLVIENDO?',
    hint: 'El bug, la duda o la meta que arrancó todo esto.',
  ),
  _GuidedQuestion(
    label: '¿QUÉ FUENTES USASTE? (charlas, libros, personas, artículos)',
    hint: 'Todo lo que leíste, viste o consultaste en el camino.',
  ),
  _GuidedQuestion(
    label: '¿QUÉ INTENTASTE PRIMERO Y NO FUNCIONÓ?',
    hint: 'El primer enfoque que probaste, aunque haya fracasado.',
  ),
  _GuidedQuestion(
    label: '¿HUBO UN CAMBIO DE ENFOQUE? ¿QUÉ LO CAUSÓ?',
    hint: 'El momento donde algo te hizo cambiar de rumbo.',
  ),
  _GuidedQuestion(
    label: '¿CÓMO TERMINASTE RESOLVIÉNDOLO?',
    hint: 'El resultado final: qué patrón, decisión o solución usaste.',
  ),
];

/// The guided path through Operación: síntesis's input — one question at a
/// time instead of a blank text field, so the devlog that reaches the
/// generator actually covers what makes a rich graph (a real problem, real
/// sources, a real turning point) instead of whatever the user happens to
/// free-write. Answers are required to advance: the whole point is to
/// force a complete description rather than let a thin one slip through.
class GuidedInputFlow extends StatefulWidget {
  const GuidedInputFlow({super.key, required this.onComplete, required this.loading});

  /// Called with the combined, labeled answers once the last step is
  /// confirmed — the same free-text contract [InputScreen] already sends
  /// to the generator, just assembled instead of hand-typed.
  final ValueChanged<String> onComplete;
  final bool loading;

  @override
  State<GuidedInputFlow> createState() => _GuidedInputFlowState();
}

class _GuidedInputFlowState extends State<GuidedInputFlow> {
  int _step = 0;
  final List<TextEditingController> _controllers = [
    for (final _ in _questions) TextEditingController(),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _currentAnswered => _controllers[_step].text.trim().isNotEmpty;

  void _next() {
    if (!_currentAnswered) return;
    if (_step == _questions.length - 1) {
      _submit();
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _submit() {
    final buffer = StringBuffer();
    for (var i = 0; i < _questions.length; i++) {
      buffer
        ..writeln(_questions[i].label)
        ..writeln(_controllers[i].text.trim())
        ..writeln();
    }
    widget.onComplete(buffer.toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final question = _questions[_step];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => HudBlockProgress(
            width: constraints.maxWidth,
            height: 10,
            blockCount: _questions.length,
            progress: (_step + 1) / _questions.length,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PASO ${_step + 1} DE ${_questions.length}',
          style: HudText.terminal(c.textDim, size: 11),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.label, style: HudText.operativa(c.text, size: 17)),
                const SizedBox(height: 8),
                Text(question.hint, style: HudText.terminal(c.textDim, size: 12)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: HudChamferedBox(
                    fill: c.panel,
                    borderColor: c.text,
                    borderWidth: 1.5,
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        key: ValueKey(_step),
                        controller: _controllers[_step],
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(color: c.text, fontSize: 14),
                        cursorColor: c.sys,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Escribe tu respuesta...',
                          hintStyle: TextStyle(color: c.textDim),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: InkWell(
                  onTap: widget.loading ? null : _back,
                  child: HudChamferedBox(
                    fill: Colors.transparent,
                    borderColor: c.textDim,
                    borderWidth: 1.5,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Center(
                      child: Text('ANTERIOR', style: HudText.operativa(c.textDim, size: 14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: widget.loading
                  ? const Center(child: HudSyncIndicator())
                  : HudButton(
                      label: _step == _questions.length - 1 ? 'GENERAR' : 'SIGUIENTE',
                      onPressed: _currentAnswered ? _next : null,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

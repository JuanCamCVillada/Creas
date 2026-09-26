import 'package:flutter/material.dart';

import '../../storage/api_key_store.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import '../theme/hud_widgets.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key, required this.apiKeyStore});

  final ApiKeyStore apiKeyStore;

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.apiKeyStore.getApiKey().then((key) {
      if (key != null && mounted) {
        _controller.text = key;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.apiKeyStore.setApiKey(_controller.text.trim());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const HudIdBadge(label: 'Credencial del sistema')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('CLAVE GEMINI:', style: HudText.operativa(c.text2, size: 12)),
            const SizedBox(height: 6),
            HudChamferedBox(
              fill: c.panel,
              borderColor: c.grid,
              borderWidth: 1,
              child: TextField(
                controller: _controller,
                obscureText: true,
                style: HudText.terminal(c.text, size: 14),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 16),
            HudButton(label: 'GUARDAR', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

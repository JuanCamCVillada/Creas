import 'package:flutter/material.dart';

import '../../engine/api_key_validator.dart';
import '../../engine/llm_provider.dart';
import '../../storage/api_key_store.dart';
import '../theme/hud_alerts.dart';
import '../theme/hud_tokens.dart';
import '../theme/hud_text.dart';
import '../theme/hud_widgets.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key, required this.apiKeyStore, this.validator});

  final ApiKeyStore apiKeyStore;

  /// Checks a key against its provider before saving. Defaults to the real
  /// thing; tests pass a fake so they never touch the network.
  final ApiKeyValidator? validator;

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _controller = TextEditingController();
  late final ApiKeyValidator _validator = widget.validator ?? LiveApiKeyValidator();

  /// null = AUTO: the provider is detected from the key itself.
  LlmProvider? _manualProvider;
  bool _checking = false;
  KeyCheckResult? _result;

  @override
  void initState() {
    super.initState();
    widget.apiKeyStore.getApiKey().then((key) {
      if (key != null && mounted) setState(() => _controller.text = key);
    });
    widget.apiKeyStore.getProvider().then((provider) {
      if (mounted) setState(() => _manualProvider = provider);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    final result = await _validator.validate(_controller.text, provider: _manualProvider);
    if (!mounted) return;
    if (result.status == KeyCheckStatus.valid) {
      await _persist();
    } else {
      setState(() {
        _checking = false;
        _result = result;
      });
    }
  }

  Future<void> _persist() async {
    await widget.apiKeyStore.setApiKey(_controller.text.trim());
    await widget.apiKeyStore.setProvider(_manualProvider);
    if (mounted) Navigator.of(context).pop();
  }

  void _selectProvider(int tabIndex) => setState(() {
        _manualProvider = tabIndex == 0 ? null : LlmProvider.values[tabIndex - 1];
        _result = null;
      });

  /// What the "PROVEEDOR" readout says and in which color — the visible
  /// answer to "which provider will this key use?".
  (String, Color) _providerReadout(HudColors c) {
    final key = _controller.text;
    final manual = _manualProvider;
    if (manual != null) return ('${manual.label} · MANUAL', c.sys);
    if (key.trim().isEmpty) return ('—', c.textDim);
    if (isAnthropicKey(key)) return ('ANTHROPIC · NO SOPORTADO', c.deny);
    final detected = detectProvider(key);
    if (detected != null) return ('${detected.label} · AUTO', c.ok);
    return ('NO RECONOCIDO · ELIGE UNO', c.caution);
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final (readoutText, readoutColor) = _providerReadout(c);
    final result = _result;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const HudIdBadge(label: 'Credencial del sistema')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('CLAVE DE API:', style: HudText.operativa(c.text2, size: 12)),
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
                onChanged: (_) => setState(() => _result = null),
              ),
            ),
            const SizedBox(height: 16),
            Text('PROVEEDOR:', style: HudText.operativa(c.text2, size: 12)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: HudSegmentedTabs(
                labels: const ['AUTO', 'GEMINI', 'OPENAI'],
                selectedIndex: _manualProvider == null ? 0 : _manualProvider!.index + 1,
                onSelected: _checking ? (_) {} : _selectProvider,
              ),
            ),
            const SizedBox(height: 10),
            Text(readoutText, style: HudText.terminal(readoutColor, size: 13)),
            const SizedBox(height: 6),
            Text(
              'AUTO detecta el proveedor por el formato de la clave '
              '(AIza… = Gemini, sk-… = OpenAI). Elige uno si no lo reconoce.',
              style: HudText.terminal(c.textDim, size: 11),
            ),
            if (result != null) ...[
              const SizedBox(height: 16),
              _ResultBanner(result: result, onSaveAnyway: _persist),
            ],
            const SizedBox(height: 16),
            _checking
                ? const Center(child: HudSyncIndicator(label: 'VERIFICANDO CLAVE'))
                : HudButton(label: 'VALIDAR Y GUARDAR', onPressed: _validateAndSave),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, required this.onSaveAnyway});

  final KeyCheckResult result;
  final VoidCallback onSaveAnyway;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    // Couldn't reach the provider: the key isn't known to be wrong, so it
    // stays savable (a precaución). Anything else is a refusal.
    if (result.status == KeyCheckStatus.unverified) {
      return HudHazardBanner(
        status: HudStatus.precaucion,
        glyph: '注意',
        title: 'NO SE PUDO VERIFICAR',
        subtitle: result.message,
        actions: [
          TextButton(
            onPressed: onSaveAnyway,
            child: Text('GUARDAR IGUAL', style: HudText.operativa(c.caution, size: 12)),
          ),
        ],
      );
    }
    return HudHazardBanner(
      status: HudStatus.emergencia,
      glyph: '否定',
      title: 'CLAVE NO ACEPTADA',
      subtitle: result.message,
    );
  }
}

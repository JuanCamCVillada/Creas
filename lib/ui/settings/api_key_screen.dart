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

  /// null = AUTO: the provider is detected from the key being added.
  LlmProvider? _manualProvider;
  bool _checking = false;
  KeyCheckResult? _result;

  /// The provider whose key was just saved, for a one-line confirmation.
  LlmProvider? _justAdded;

  Map<LlmProvider, String> _keys = {};
  LlmProvider? _storedPrimary;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final keys = <LlmProvider, String>{};
    for (final provider in LlmProvider.values) {
      final key = await widget.apiKeyStore.getKey(provider);
      if (key != null && key.isNotEmpty) keys[provider] = key;
    }
    final primary = await widget.apiKeyStore.getPrimary();
    if (!mounted) return;
    setState(() {
      _keys = keys;
      _storedPrimary = primary;
    });
  }

  /// Configured providers in the order they'll be tried — the same rule the
  /// engine uses, so this screen shows what will really happen.
  List<LlmProvider> get _order {
    final configured = LlmProvider.values.where(_keys.containsKey).toList();
    final primary = _storedPrimary;
    if (primary != null && configured.contains(primary)) {
      configured
        ..remove(primary)
        ..insert(0, primary);
    }
    return configured;
  }

  /// Which provider a key being added belongs to.
  LlmProvider _targetFor(KeyCheckResult? result) =>
      result?.provider ??
      _manualProvider ??
      detectProvider(_controller.text) ??
      LlmProvider.gemini;

  Future<void> _validateAndAdd() async {
    setState(() {
      _checking = true;
      _result = null;
      _justAdded = null;
    });
    final result = await _validator.validate(_controller.text, provider: _manualProvider);
    if (!mounted) return;
    if (result.status == KeyCheckStatus.valid) {
      await _add(_targetFor(result));
    } else {
      setState(() {
        _checking = false;
        _result = result;
      });
    }
  }

  Future<void> _add(LlmProvider provider) async {
    await widget.apiKeyStore.setKey(provider, _controller.text.trim());
    _controller.clear();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = null;
      _justAdded = provider;
    });
    await _reload();
  }

  Future<void> _makePrimary(LlmProvider provider) async {
    await widget.apiKeyStore.setPrimary(provider);
    await _reload();
  }

  Future<void> _confirmRemove(LlmProvider provider) async {
    final c = HudColors.consola;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.panel,
        title: Text('QUITAR CLAVE DE ${provider.label}',
            style: HudText.operativa(c.text, size: 16)),
        content: Text(
          'Se borra de este dispositivo. Para volver a usarla tendrás que '
          'pegarla otra vez.',
          style: HudText.terminal(c.text2, size: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('CANCELAR', style: HudText.operativa(c.textDim, size: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('QUITAR', style: HudText.operativa(c.deny, size: 13)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.apiKeyStore.removeKey(provider);
    await _reload();
  }

  void _selectProvider(int tabIndex) => setState(() {
        _manualProvider = tabIndex == 0 ? null : LlmProvider.values[tabIndex - 1];
        _result = null;
        _justAdded = null;
      });

  /// What the "PROVEEDOR" readout says and in which color — the visible
  /// answer to "which provider will this key be added to?".
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

  /// One line saying what happens when a provider fails — the point of
  /// having more than one key.
  (String, Color) _backupSummary(HudColors c) {
    final order = _order;
    if (order.isEmpty) return ('SIN CLAVES · AGREGA UNA PARA GENERAR.', c.textDim);
    if (order.length == 1) {
      final missing = LlmProvider.values.where((p) => !_keys.containsKey(p)).map((p) => p.label);
      return (
        'SIN RESPALDO · si ${order.first.label} falla, no hay a quién delegar. '
        'Agrega una clave de ${missing.join(' u ')} para tenerlo.',
        c.caution,
      );
    }
    final next = order.skip(1).map((p) => p.label).join(' → ');
    return (
      'RESPALDO ACTIVO · si ${order.first.label} falla, se usa $next '
      'automáticamente.',
      c.ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final (readoutText, readoutColor) = _providerReadout(c);
    final (summaryText, summaryColor) = _backupSummary(c);
    final result = _result;
    final order = _order;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const HudIdBadge(label: 'Credencial del sistema')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AGREGAR CLAVE:', style: HudText.operativa(c.text2, size: 12)),
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
                onChanged: (_) => setState(() {
                  _result = null;
                  _justAdded = null;
                }),
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
              _ResultBanner(
                result: result,
                onSaveAnyway: () => _add(_targetFor(result)),
              ),
            ],
            const SizedBox(height: 16),
            _checking
                ? const Center(child: HudSyncIndicator(label: 'VERIFICANDO CLAVE'))
                : HudButton(label: 'VALIDAR Y AGREGAR', onPressed: _validateAndAdd),
            if (_justAdded != null) ...[
              const SizedBox(height: 10),
              Text('承認 · CLAVE DE ${_justAdded!.label} GUARDADA',
                  style: HudText.terminal(c.ok, size: 12)),
            ],
            const SizedBox(height: 28),
            Text('PROVEEDORES:', style: HudText.operativa(c.text2, size: 12)),
            const SizedBox(height: 8),
            for (final provider in LlmProvider.values) ...[
              _ProviderCard(
                provider: provider,
                maskedKey: _keys.containsKey(provider) ? _mask(_keys[provider]!) : null,
                isPrimary: order.isNotEmpty && order.first == provider,
                canMakePrimary:
                    _keys.containsKey(provider) && order.length > 1 && order.first != provider,
                onMakePrimary: () => _makePrimary(provider),
                onRemove: () => _confirmRemove(provider),
              ),
              const SizedBox(height: 10),
            ],
            Text(summaryText, style: HudText.terminal(summaryColor, size: 12)),
          ],
        ),
      ),
    );
  }

  /// Enough of the key to recognize it, never the whole thing.
  static String _mask(String key) =>
      key.length >= 8 ? '····${key.substring(key.length - 4)}' : '····';
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.maskedKey,
    required this.isPrimary,
    required this.canMakePrimary,
    required this.onMakePrimary,
    required this.onRemove,
  });

  final LlmProvider provider;

  /// null when this provider has no key.
  final String? maskedKey;
  final bool isPrimary;
  final bool canMakePrimary;
  final VoidCallback onMakePrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final configured = maskedKey != null;
    return HudChamferedBox(
      fill: c.panel,
      borderColor: isPrimary ? c.sys : c.grid,
      borderWidth: isPrimary ? 1.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(provider.label,
                  style: HudText.operativa(configured ? c.text : c.textDim, size: 15)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  configured ? maskedKey! : 'SIN CLAVE',
                  overflow: TextOverflow.ellipsis,
                  style: HudText.terminal(configured ? c.ok : c.textDim, size: 12),
                ),
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: c.sys)),
                  child: Text('PRINCIPAL', style: HudText.operativa(c.sys, size: 11)),
                ),
            ],
          ),
          if (configured)
            Wrap(
              children: [
                if (canMakePrimary)
                  TextButton(
                    onPressed: onMakePrimary,
                    child: Text('HACER PRINCIPAL', style: HudText.operativa(c.sys, size: 12)),
                  ),
                TextButton(
                  onPressed: onRemove,
                  child: Text('QUITAR', style: HudText.operativa(c.deny, size: 12)),
                ),
              ],
            ),
        ],
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

import 'package:flutter/material.dart';

import '../../engine/graph_generator.dart';
import '../../storage/session_store.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _error = null),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Pega tu devlog, retro o transcripción...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _generate,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generar'),
            ),
          ],
        ),
      ),
    );
  }
}

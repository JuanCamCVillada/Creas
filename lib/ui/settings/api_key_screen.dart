import 'package:flutter/material.dart';

import '../../storage/api_key_store.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Clave de API de Anthropic')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Clave de API'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}

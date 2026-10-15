import 'package:flutter/material.dart';

import 'engine/graph_generator.dart';
import 'storage/api_key_store.dart';
import 'storage/session_store.dart';
import 'ui/sessions/session_list_screen.dart';
import 'ui/theme/hud_tokens.dart';

class CreativeApp extends StatelessWidget {
  const CreativeApp({
    super.key,
    required this.sessionStore,
    required this.apiKeyStore,
    required this.generator,
    this.scaffoldMessengerKey,
  });

  final SessionStore sessionStore;
  final ApiKeyStore apiKeyStore;
  final GraphGenerator generator;

  /// Lets code outside the widget tree (the generation engine reporting a
  /// failover) show a SnackBar on whichever screen is current.
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Genealogía Creativa',
      theme: _hudMaterialTheme(HudColors.dia),
      darkTheme: _hudMaterialTheme(HudColors.consola),
      themeMode: ThemeMode.system,
      home: SessionListScreen(
        sessionStore: sessionStore,
        apiKeyStore: apiKeyStore,
        generator: generator,
      ),
    );
  }

  ThemeData _hudMaterialTheme(HudColors c) {
    final isDark = identical(c, HudColors.consola);
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.sys,
        onPrimary: c.bg,
        secondary: c.struct,
        onSecondary: c.text,
        surface: c.panel,
        onSurface: c.text,
        error: c.deny,
        onError: c.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

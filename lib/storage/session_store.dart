import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

abstract class SessionStore {
  Future<List<GraphSession>> listSessions();
  Future<void> saveSession(GraphSession session);
  Future<void> deleteSession(String id);
}

class LocalSessionStore implements SessionStore {
  LocalSessionStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'graph_sessions';

  @override
  Future<List<GraphSession>> listSessions() async {
    final raw = _prefs.getStringList(_key) ?? const [];
    final sessions = raw
        .map((s) => GraphSession.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  @override
  Future<void> saveSession(GraphSession session) async {
    final raw = _prefs.getStringList(_key) ?? const [];
    final updated = [...raw, jsonEncode(session.toJson())];
    await _prefs.setStringList(_key, updated);
  }

  @override
  Future<void> deleteSession(String id) async {
    final sessions = await listSessions();
    final updated = sessions
        .where((s) => s.id != id)
        .map((s) => jsonEncode(s.toJson()))
        .toList();
    await _prefs.setStringList(_key, updated);
  }
}

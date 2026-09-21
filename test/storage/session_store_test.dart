import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:creative/storage/session_store.dart';
import 'package:creative/models/session.dart';
import 'package:creative/models/creative_graph.dart';

GraphSession _session(String id, DateTime createdAt) => GraphSession(
      id: id,
      rawInput: 'input $id',
      graph: const CreativeGraph(
        nodes: [],
        edges: [],
        affinityEdges: [],
        turningPoints: [],
        followupQuestions: [],
      ),
      createdAt: createdAt,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalSessionStore', () {
    test('listSessions returns an empty list initially', () async {
      final store = LocalSessionStore(await SharedPreferences.getInstance());
      expect(await store.listSessions(), isEmpty);
    });

    test('saveSession then listSessions returns it, newest first', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LocalSessionStore(prefs);

      await store.saveSession(_session('1', DateTime.utc(2026, 1, 1)));
      await store.saveSession(_session('2', DateTime.utc(2026, 6, 1)));

      final sessions = await store.listSessions();
      expect(sessions.map((s) => s.id).toList(), ['2', '1']);
    });

    test('deleteSession removes only the matching session', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LocalSessionStore(prefs);

      await store.saveSession(_session('1', DateTime.utc(2026, 1, 1)));
      await store.saveSession(_session('2', DateTime.utc(2026, 6, 1)));
      await store.deleteSession('1');

      final sessions = await store.listSessions();
      expect(sessions.map((s) => s.id).toList(), ['2']);
    });
  });
}

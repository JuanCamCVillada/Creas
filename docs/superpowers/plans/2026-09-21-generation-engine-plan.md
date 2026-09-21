# Generation Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the end-to-end generation engine for Genealogía Creativa: text input → Anthropic tool-call → parsed/verified graph → local persistence → Jardín Digital and Árbol Genealógico views.

**Architecture:** Five layers (input UI → generation engine → verification → local store → view renderers), each independently testable. Models are plain immutable Dart classes with explicit `fromJson`/`toJson`. The Anthropic call and persistence are hidden behind small interfaces (`GraphGenerationClient`, `GraphGenerator`, `ApiKeyStore`, `SessionStore`) so business logic and UI can be tested with in-memory fakes instead of hitting real plugins or the network.

**Tech Stack:** Flutter/Dart, `http` (Anthropic API calls), `flutter_secure_storage` (API key), `shared_preferences` (session persistence), `graphview` (force-directed + layered graph rendering), `collection` (equality helpers).

**Spec:** [docs/superpowers/specs/2026-09-21-generation-engine-design.md](../specs/2026-09-21-generation-engine-design.md)

## Global Constraints

- Model: `claude-sonnet-5`, called via forced tool use (`tool_choice: {type: "tool", name: "emit_creative_graph"}`) — never free text.
- Text input only in this iteration — no audio recording/transcription.
- User supplies their own Anthropic API key; stored via `flutter_secure_storage`, never sent anywhere but the Anthropic API.
- No backend proxy — the app calls `https://api.anthropic.com/v1/messages` directly.
- Sessions persist locally via `shared_preferences` as JSON blobs — no native DB dependency (must work on web).
- Turning points are proposed by the model but only surfaced after passing code-side structural verification (convergence + direction-change) defined in the spec — never trust the model's self-assessment.
- Lineage edges (`edges`) must be acyclic; a cycle is a hard rejection with a regenerate prompt, never silently dropped.
- Target platforms: web, iOS, Android — no platform-specific plugins without web support.
- Labels/descriptions preserve the user's own language and vocabulary — the system prompt must not rewrite them.

---

## File Structure

```
lib/
  models/
    node.dart
    lineage_edge.dart
    affinity_edge.dart
    turning_point.dart
    creative_graph.dart
    session.dart
  engine/
    tool_schema.dart
    system_prompt.dart
    graph_parser.dart
    graph_verifier.dart
    graph_generation_client.dart   # interface + AnthropicApiException
    anthropic_client.dart          # AnthropicClient implements GraphGenerationClient
    graph_generator.dart           # interface + GenerationFailedException
    generation_engine.dart         # GenerationEngine implements GraphGenerator
  storage/
    api_key_store.dart             # interface + SecureApiKeyStore
    session_store.dart             # interface + LocalSessionStore
  ui/
    settings/api_key_screen.dart
    sessions/session_list_screen.dart
    input/input_screen.dart
    graph/graph_view_screen.dart
    graph/jardin_digital_view.dart
    graph/arbol_genealogico_view.dart
    graph/node_detail_sheet.dart
    graph/turning_point_badge.dart
  app.dart
  main.dart
test/
  helpers/fakes.dart
  models/*_test.dart
  engine/*_test.dart
  storage/*_test.dart
  ui/*_test.dart
  widget_test.dart
```

---

## Task 1: Project setup — add dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies**

Edit the `dependencies:` block to:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.6.0
  flutter_secure_storage: ^11.2.0
  shared_preferences: ^2.5.5
  graphview: ^1.5.1
  collection: ^1.19.1
```

- [ ] **Step 2: Run `flutter pub get` and verify it succeeds**

Run: `flutter pub get`
Expected: exits 0, `pubspec.lock` updated with the five new packages.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add generation engine dependencies"
```

---

## Task 2: Node model

**Files:**
- Create: `lib/models/node.dart`
- Test: `test/models/node_test.dart`

**Interfaces:**
- Produces: `enum NodeType { fuente, concepto }`, `enum NodeOrigin { usuario, sugerido }`, `class Node { final String id, type (NodeType), label, description, cluster; final NodeOrigin origin; final double? confidence; final String? timestamp, referenteOf; final int? sequence, level; factory Node.fromJson(Map<String,dynamic>); Map<String,dynamic> toJson(); }`. Throws `FormatException` on an unknown `type`/`origin` string.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/node_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/node.dart';

void main() {
  group('Node', () {
    test('fromJson parses a full fuente node', () {
      final node = Node.fromJson({
        'id': 's1',
        'type': 'fuente',
        'label': 'El pico del martín pescador',
        'description': 'La forma que inspiró el morro del Shinkansen',
        'cluster': 'biologia',
        'origin': 'usuario',
        'timestamp': '2024-03-01',
        'sequence': null,
      });

      expect(node.id, 's1');
      expect(node.type, NodeType.fuente);
      expect(node.label, 'El pico del martín pescador');
      expect(node.cluster, 'biologia');
      expect(node.origin, NodeOrigin.usuario);
      expect(node.timestamp, '2024-03-01');
      expect(node.confidence, isNull);
      expect(node.level, isNull);
      expect(node.referenteOf, isNull);
    });

    test('fromJson parses a suggested concepto node with confidence and level', () {
      final node = Node.fromJson({
        'id': 'c1',
        'type': 'concepto',
        'label': 'Arquitectura hexagonal',
        'description': 'Separar el dominio de la infraestructura',
        'cluster': 'arquitectura-software',
        'origin': 'sugerido',
        'confidence': 0.7,
        'sequence': 3,
        'level': 2,
        'referente_of': 'f1',
      });

      expect(node.origin, NodeOrigin.sugerido);
      expect(node.confidence, 0.7);
      expect(node.sequence, 3);
      expect(node.level, 2);
      expect(node.referenteOf, 'f1');
    });

    test('fromJson throws FormatException on unknown type', () {
      expect(
        () => Node.fromJson({
          'id': 'x',
          'type': 'bogus',
          'label': 'a',
          'description': 'b',
          'cluster': 'c',
          'origin': 'usuario',
        }),
        throwsFormatException,
      );
    });

    test('toJson round-trips through fromJson', () {
      const original = Node(
        id: 'c2',
        type: NodeType.concepto,
        label: 'BLoC',
        description: 'Segundo intento de manejo de estado',
        cluster: 'arquitectura-software',
        origin: NodeOrigin.usuario,
        sequence: 2,
      );

      final roundTripped = Node.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.type, original.type);
      expect(roundTripped.sequence, original.sequence);
      expect(roundTripped.confidence, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/node_test.dart`
Expected: FAIL — `lib/models/node.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/node.dart
enum NodeType { fuente, concepto }

enum NodeOrigin { usuario, sugerido }

class Node {
  const Node({
    required this.id,
    required this.type,
    required this.label,
    required this.description,
    required this.cluster,
    required this.origin,
    this.confidence,
    this.timestamp,
    this.sequence,
    this.level,
    this.referenteOf,
  });

  final String id;
  final NodeType type;
  final String label;
  final String description;
  final String cluster;
  final NodeOrigin origin;
  final double? confidence;
  final String? timestamp;
  final int? sequence;
  final int? level;
  final String? referenteOf;

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] as String,
      type: _parseType(json['type'] as String),
      label: json['label'] as String,
      description: json['description'] as String,
      cluster: json['cluster'] as String,
      origin: _parseOrigin(json['origin'] as String),
      confidence: (json['confidence'] as num?)?.toDouble(),
      timestamp: json['timestamp'] as String?,
      sequence: (json['sequence'] as num?)?.toInt(),
      level: (json['level'] as num?)?.toInt(),
      referenteOf: json['referente_of'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == NodeType.fuente ? 'fuente' : 'concepto',
        'label': label,
        'description': description,
        'cluster': cluster,
        'origin': origin == NodeOrigin.usuario ? 'usuario' : 'sugerido',
        if (confidence != null) 'confidence': confidence,
        if (timestamp != null) 'timestamp': timestamp,
        if (sequence != null) 'sequence': sequence,
        if (level != null) 'level': level,
        if (referenteOf != null) 'referente_of': referenteOf,
      };

  static NodeType _parseType(String raw) {
    switch (raw) {
      case 'fuente':
        return NodeType.fuente;
      case 'concepto':
        return NodeType.concepto;
      default:
        throw FormatException('tipo de nodo desconocido: $raw');
    }
  }

  static NodeOrigin _parseOrigin(String raw) {
    switch (raw) {
      case 'usuario':
        return NodeOrigin.usuario;
      case 'sugerido':
        return NodeOrigin.sugerido;
      default:
        throw FormatException('origen de nodo desconocido: $raw');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node &&
          id == other.id &&
          type == other.type &&
          label == other.label &&
          description == other.description &&
          cluster == other.cluster &&
          origin == other.origin &&
          confidence == other.confidence &&
          timestamp == other.timestamp &&
          sequence == other.sequence &&
          level == other.level &&
          referenteOf == other.referenteOf;

  @override
  int get hashCode => Object.hash(id, type, label, description, cluster,
      origin, confidence, timestamp, sequence, level, referenteOf);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/node_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/models/node.dart test/models/node_test.dart
git commit -m "feat: add Node model"
```

---

## Task 3: LineageEdge model

**Files:**
- Create: `lib/models/lineage_edge.dart`
- Test: `test/models/lineage_edge_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `enum LineageRelation { desencadena, derivaDe, inspira, transformaEn }`, `class LineageEdge { final String id, source, target; final LineageRelation relation; factory LineageEdge.fromJson(...); Map<String,dynamic> toJson(); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/lineage_edge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/lineage_edge.dart';

void main() {
  group('LineageEdge', () {
    test('fromJson parses all four relation verbs', () {
      final cases = {
        'desencadena': LineageRelation.desencadena,
        'deriva_de': LineageRelation.derivaDe,
        'inspira': LineageRelation.inspira,
        'transforma_en': LineageRelation.transformaEn,
      };

      for (final entry in cases.entries) {
        final edge = LineageEdge.fromJson({
          'id': 'e1',
          'source': 's1',
          'target': 'c1',
          'relation': entry.key,
        });
        expect(edge.relation, entry.value, reason: entry.key);
      }
    });

    test('fromJson throws FormatException on unknown relation', () {
      expect(
        () => LineageEdge.fromJson({
          'id': 'e1',
          'source': 's1',
          'target': 'c1',
          'relation': 'bogus',
        }),
        throwsFormatException,
      );
    });

    test('toJson round-trips', () {
      const original = LineageEdge(
        id: 'e2',
        source: 'c1',
        target: 'c2',
        relation: LineageRelation.transformaEn,
      );
      final roundTripped = LineageEdge.fromJson(original.toJson());
      expect(roundTripped, original);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/lineage_edge_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/lineage_edge.dart
enum LineageRelation { desencadena, derivaDe, inspira, transformaEn }

class LineageEdge {
  const LineageEdge({
    required this.id,
    required this.source,
    required this.target,
    required this.relation,
  });

  final String id;
  final String source;
  final String target;
  final LineageRelation relation;

  factory LineageEdge.fromJson(Map<String, dynamic> json) {
    return LineageEdge(
      id: json['id'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      relation: _parseRelation(json['relation'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'target': target,
        'relation': _relationToJson(relation),
      };

  static LineageRelation _parseRelation(String raw) {
    switch (raw) {
      case 'desencadena':
        return LineageRelation.desencadena;
      case 'deriva_de':
        return LineageRelation.derivaDe;
      case 'inspira':
        return LineageRelation.inspira;
      case 'transforma_en':
        return LineageRelation.transformaEn;
      default:
        throw FormatException('relación de linaje desconocida: $raw');
    }
  }

  static String _relationToJson(LineageRelation relation) {
    switch (relation) {
      case LineageRelation.desencadena:
        return 'desencadena';
      case LineageRelation.derivaDe:
        return 'deriva_de';
      case LineageRelation.inspira:
        return 'inspira';
      case LineageRelation.transformaEn:
        return 'transforma_en';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineageEdge &&
          id == other.id &&
          source == other.source &&
          target == other.target &&
          relation == other.relation;

  @override
  int get hashCode => Object.hash(id, source, target, relation);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/lineage_edge_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/models/lineage_edge.dart test/models/lineage_edge_test.dart
git commit -m "feat: add LineageEdge model"
```

---

## Task 4: AffinityEdge model

**Files:**
- Create: `lib/models/affinity_edge.dart`
- Test: `test/models/affinity_edge_test.dart`

**Interfaces:**
- Produces: `class AffinityEdge { final String source, target; final double weight; factory AffinityEdge.fromJson(...); Map<String,dynamic> toJson(); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/affinity_edge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/affinity_edge.dart';

void main() {
  group('AffinityEdge', () {
    test('fromJson parses source, target and weight', () {
      final edge = AffinityEdge.fromJson({
        'source': 'a',
        'target': 'b',
        'weight': 0.8,
      });
      expect(edge.source, 'a');
      expect(edge.target, 'b');
      expect(edge.weight, 0.8);
    });

    test('toJson round-trips', () {
      const original = AffinityEdge(source: 'x', target: 'y', weight: 0.3);
      final roundTripped = AffinityEdge.fromJson(original.toJson());
      expect(roundTripped, original);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/affinity_edge_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/affinity_edge.dart
class AffinityEdge {
  const AffinityEdge({
    required this.source,
    required this.target,
    required this.weight,
  });

  final String source;
  final String target;
  final double weight;

  factory AffinityEdge.fromJson(Map<String, dynamic> json) => AffinityEdge(
        source: json['source'] as String,
        target: json['target'] as String,
        weight: (json['weight'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target,
        'weight': weight,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AffinityEdge &&
          source == other.source &&
          target == other.target &&
          weight == other.weight;

  @override
  int get hashCode => Object.hash(source, target, weight);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/affinity_edge_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/models/affinity_edge.dart test/models/affinity_edge_test.dart
git commit -m "feat: add AffinityEdge model"
```

---

## Task 5: TurningPoint model

**Files:**
- Create: `lib/models/turning_point.dart`
- Test: `test/models/turning_point_test.dart`

**Interfaces:**
- Produces: `class TurningPoint { final String nodeId, evidence; final bool convergence, directionChange; bool get isVerified; const TurningPoint({required nodeId, required evidence, convergence=false, directionChange=false}); factory TurningPoint.fromCandidateJson(Map<String,dynamic>); TurningPoint copyWith({bool? convergence, bool? directionChange}); Map<String,dynamic> toJson(); factory TurningPoint.fromJson(Map<String,dynamic>); }`. `fromCandidateJson` reads the LLM's `{node_id, evidence}` shape and leaves both flags at their `false` default (unverified). `fromJson`/`toJson` are the full round-trip shape used by persistence, including the flags.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/turning_point_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/turning_point.dart';

void main() {
  group('TurningPoint', () {
    test('fromCandidateJson parses node_id and evidence, unverified by default', () {
      final tp = TurningPoint.fromCandidateJson({
        'node_id': 'c3',
        'evidence': 'El bug de memoria y la charla de bases de datos convergieron aquí',
      });
      expect(tp.nodeId, 'c3');
      expect(tp.convergence, isFalse);
      expect(tp.directionChange, isFalse);
      expect(tp.isVerified, isFalse);
    });

    test('isVerified is true only when both flags are true', () {
      const tp = TurningPoint(
        nodeId: 'c3',
        evidence: 'e',
        convergence: true,
        directionChange: true,
      );
      expect(tp.isVerified, isTrue);
    });

    test('copyWith updates only the given flags', () {
      const tp = TurningPoint(nodeId: 'c3', evidence: 'e');
      final updated = tp.copyWith(convergence: true);
      expect(updated.convergence, isTrue);
      expect(updated.directionChange, isFalse);
      expect(updated.nodeId, 'c3');
    });

    test('toJson/fromJson round-trips including flags', () {
      const tp = TurningPoint(
        nodeId: 'c3',
        evidence: 'e',
        convergence: true,
        directionChange: true,
      );
      final roundTripped = TurningPoint.fromJson(tp.toJson());
      expect(roundTripped, tp);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/turning_point_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/turning_point.dart
class TurningPoint {
  const TurningPoint({
    required this.nodeId,
    required this.evidence,
    this.convergence = false,
    this.directionChange = false,
  });

  final String nodeId;
  final String evidence;
  final bool convergence;
  final bool directionChange;

  bool get isVerified => convergence && directionChange;

  factory TurningPoint.fromCandidateJson(Map<String, dynamic> json) {
    return TurningPoint(
      nodeId: json['node_id'] as String,
      evidence: json['evidence'] as String,
    );
  }

  factory TurningPoint.fromJson(Map<String, dynamic> json) {
    return TurningPoint(
      nodeId: json['node_id'] as String,
      evidence: json['evidence'] as String,
      convergence: json['convergence'] as bool? ?? false,
      directionChange: json['direction_change'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'node_id': nodeId,
        'evidence': evidence,
        'convergence': convergence,
        'direction_change': directionChange,
      };

  TurningPoint copyWith({bool? convergence, bool? directionChange}) {
    return TurningPoint(
      nodeId: nodeId,
      evidence: evidence,
      convergence: convergence ?? this.convergence,
      directionChange: directionChange ?? this.directionChange,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TurningPoint &&
          nodeId == other.nodeId &&
          evidence == other.evidence &&
          convergence == other.convergence &&
          directionChange == other.directionChange;

  @override
  int get hashCode =>
      Object.hash(nodeId, evidence, convergence, directionChange);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/turning_point_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/models/turning_point.dart test/models/turning_point_test.dart
git commit -m "feat: add TurningPoint model"
```

---

## Task 6: CreativeGraph model

**Files:**
- Create: `lib/models/creative_graph.dart`
- Test: `test/models/creative_graph_test.dart`

**Interfaces:**
- Consumes: `Node`, `LineageEdge`, `AffinityEdge`, `TurningPoint` (Tasks 2–5).
- Produces: `class CreativeGraph { final List<Node> nodes; final List<LineageEdge> edges; final List<AffinityEdge> affinityEdges; final List<TurningPoint> turningPoints; final List<String> followupQuestions; const CreativeGraph({required nodes, required edges, required affinityEdges, required turningPoints, required followupQuestions}); CreativeGraph copyWith({List<TurningPoint>? turningPoints}); factory CreativeGraph.fromJson(Map<String,dynamic>); Map<String,dynamic> toJson(); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/creative_graph_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/lineage_edge.dart';
import 'package:creative/models/affinity_edge.dart';
import 'package:creative/models/turning_point.dart';

CreativeGraph _sampleGraph() => const CreativeGraph(
      nodes: [
        Node(
          id: 's1',
          type: NodeType.fuente,
          label: 'Bug de memoria',
          description: 'Un leak en producción',
          cluster: 'infraestructura',
          origin: NodeOrigin.usuario,
        ),
        Node(
          id: 'c1',
          type: NodeType.concepto,
          label: 'Cache manual',
          description: 'Primer intento',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.usuario,
        ),
      ],
      edges: [
        LineageEdge(
          id: 'e1',
          source: 's1',
          target: 'c1',
          relation: LineageRelation.desencadena,
        ),
      ],
      affinityEdges: [AffinityEdge(source: 's1', target: 'c1', weight: 0.5)],
      turningPoints: [TurningPoint(nodeId: 'c1', evidence: 'evidencia')],
      followupQuestions: ['¿Quién te enseñó esto?'],
    );

void main() {
  group('CreativeGraph', () {
    test('toJson/fromJson round-trips the whole graph', () {
      final graph = _sampleGraph();
      final roundTripped = CreativeGraph.fromJson(graph.toJson());

      expect(roundTripped.nodes, graph.nodes);
      expect(roundTripped.edges, graph.edges);
      expect(roundTripped.affinityEdges, graph.affinityEdges);
      expect(roundTripped.turningPoints, graph.turningPoints);
      expect(roundTripped.followupQuestions, graph.followupQuestions);
    });

    test('copyWith replaces only turningPoints', () {
      final graph = _sampleGraph();
      final updated = graph.copyWith(turningPoints: const []);

      expect(updated.turningPoints, isEmpty);
      expect(updated.nodes, graph.nodes);
      expect(updated.edges, graph.edges);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/creative_graph_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/creative_graph.dart
import 'node.dart';
import 'lineage_edge.dart';
import 'affinity_edge.dart';
import 'turning_point.dart';

class CreativeGraph {
  const CreativeGraph({
    required this.nodes,
    required this.edges,
    required this.affinityEdges,
    required this.turningPoints,
    required this.followupQuestions,
  });

  final List<Node> nodes;
  final List<LineageEdge> edges;
  final List<AffinityEdge> affinityEdges;
  final List<TurningPoint> turningPoints;
  final List<String> followupQuestions;

  CreativeGraph copyWith({List<TurningPoint>? turningPoints}) {
    return CreativeGraph(
      nodes: nodes,
      edges: edges,
      affinityEdges: affinityEdges,
      turningPoints: turningPoints ?? this.turningPoints,
      followupQuestions: followupQuestions,
    );
  }

  factory CreativeGraph.fromJson(Map<String, dynamic> json) {
    return CreativeGraph(
      nodes: (json['nodes'] as List)
          .map((e) => Node.fromJson(e as Map<String, dynamic>))
          .toList(),
      edges: (json['edges'] as List)
          .map((e) => LineageEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
      affinityEdges: (json['affinity_edges'] as List)
          .map((e) => AffinityEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
      turningPoints: (json['turning_points'] as List)
          .map((e) => TurningPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      followupQuestions: (json['followup_questions'] as List)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'affinity_edges': affinityEdges.map((e) => e.toJson()).toList(),
        'turning_points': turningPoints.map((t) => t.toJson()).toList(),
        'followup_questions': followupQuestions,
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/creative_graph_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/models/creative_graph.dart test/models/creative_graph_test.dart
git commit -m "feat: add CreativeGraph aggregate model"
```

---

## Task 7: GraphSession model

**Files:**
- Create: `lib/models/session.dart`
- Test: `test/models/session_test.dart`

**Interfaces:**
- Consumes: `CreativeGraph` (Task 6).
- Produces: `class GraphSession { final String id, rawInput; final CreativeGraph graph; final DateTime createdAt; const GraphSession({required id, required rawInput, required graph, required createdAt}); factory GraphSession.fromJson(Map<String,dynamic>); Map<String,dynamic> toJson(); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/session_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/session.dart';
import 'package:creative/models/creative_graph.dart';

void main() {
  group('GraphSession', () {
    test('toJson/fromJson round-trips id, rawInput, graph and createdAt', () {
      final session = GraphSession(
        id: '123',
        rawInput: 'hoy arreglé un bug de memoria y pensé en el kingfisher',
        graph: const CreativeGraph(
          nodes: [],
          edges: [],
          affinityEdges: [],
          turningPoints: [],
          followupQuestions: [],
        ),
        createdAt: DateTime.utc(2026, 9, 21, 10, 30),
      );

      final roundTripped = GraphSession.fromJson(session.toJson());

      expect(roundTripped.id, '123');
      expect(roundTripped.rawInput, session.rawInput);
      expect(roundTripped.createdAt, session.createdAt);
      expect(roundTripped.graph.nodes, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/session_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/session.dart
import 'creative_graph.dart';

class GraphSession {
  const GraphSession({
    required this.id,
    required this.rawInput,
    required this.graph,
    required this.createdAt,
  });

  final String id;
  final String rawInput;
  final CreativeGraph graph;
  final DateTime createdAt;

  factory GraphSession.fromJson(Map<String, dynamic> json) {
    return GraphSession(
      id: json['id'] as String,
      rawInput: json['raw_input'] as String,
      graph: CreativeGraph.fromJson(json['graph'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'raw_input': rawInput,
        'graph': graph.toJson(),
        'created_at': createdAt.toIso8601String(),
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/session_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/models/session.dart test/models/session_test.dart
git commit -m "feat: add GraphSession model"
```

---

## Task 8: Tool schema for `emit_creative_graph`

**Files:**
- Create: `lib/engine/tool_schema.dart`
- Test: `test/engine/tool_schema_test.dart`

**Interfaces:**
- Produces: `const Map<String, dynamic> emitCreativeGraphToolSchema` — an Anthropic tool definition (`name`, `description`, `input_schema`) whose `input_schema.properties` cover `nodes`, `edges`, `affinity_edges`, `turning_point_candidates`, `followup_questions`, matching the JSON shapes consumed by `Node.fromJson`, `LineageEdge.fromJson`, `AffinityEdge.fromJson`, `TurningPoint.fromCandidateJson`.

- [ ] **Step 1: Write the failing test**

```dart
// test/engine/tool_schema_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/tool_schema.dart';

void main() {
  group('emitCreativeGraphToolSchema', () {
    test('has the expected top-level tool shape', () {
      expect(emitCreativeGraphToolSchema['name'], 'emit_creative_graph');
      expect(emitCreativeGraphToolSchema['description'], isNotEmpty);

      final inputSchema =
          emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>;
      expect(inputSchema['type'], 'object');

      final properties = inputSchema['properties'] as Map<String, dynamic>;
      expect(properties.keys, containsAll([
        'nodes',
        'edges',
        'affinity_edges',
        'turning_point_candidates',
        'followup_questions',
      ]));

      final required = inputSchema['required'] as List;
      expect(required, containsAll([
        'nodes',
        'edges',
        'affinity_edges',
        'turning_point_candidates',
        'followup_questions',
      ]));
    });

    test('node schema enumerates type and origin values', () {
      final inputSchema =
          emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>;
      final properties = inputSchema['properties'] as Map<String, dynamic>;
      final nodeItemSchema =
          (properties['nodes'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final nodeProperties =
          nodeItemSchema['properties'] as Map<String, dynamic>;

      expect((nodeProperties['type'] as Map)['enum'], ['fuente', 'concepto']);
      expect(
          (nodeProperties['origin'] as Map)['enum'], ['usuario', 'sugerido']);
    });

    test('edge schema enumerates the four lineage relations', () {
      final inputSchema =
          emitCreativeGraphToolSchema['input_schema'] as Map<String, dynamic>;
      final properties = inputSchema['properties'] as Map<String, dynamic>;
      final edgeItemSchema =
          (properties['edges'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final edgeProperties =
          edgeItemSchema['properties'] as Map<String, dynamic>;

      expect((edgeProperties['relation'] as Map)['enum'],
          ['desencadena', 'deriva_de', 'inspira', 'transforma_en']);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/tool_schema_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/engine/tool_schema.dart
const Map<String, dynamic> emitCreativeGraphToolSchema = {
  'name': 'emit_creative_graph',
  'description':
      'Emit the extracted creative-provenance graph: Fuente/Concepto nodes, '
      'the directed lineage between them, the undirected affinity edges for '
      'the Jardín Digital view, candidate turning points, and any follow-up '
      'questions needed when the input is too thin to build a lineage.',
  'input_schema': {
    'type': 'object',
    'properties': {
      'nodes': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'type': {
              'type': 'string',
              'enum': ['fuente', 'concepto'],
            },
            'label': {'type': 'string'},
            'description': {'type': 'string'},
            'cluster': {'type': 'string'},
            'origin': {
              'type': 'string',
              'enum': ['usuario', 'sugerido'],
            },
            'confidence': {'type': 'number'},
            'timestamp': {'type': 'string'},
            'sequence': {'type': 'integer'},
            'level': {'type': 'integer', 'enum': [1, 2]},
            'referente_of': {'type': 'string'},
          },
          'required': ['id', 'type', 'label', 'description', 'cluster', 'origin'],
        },
      },
      'edges': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'source': {'type': 'string'},
            'target': {'type': 'string'},
            'relation': {
              'type': 'string',
              'enum': ['desencadena', 'deriva_de', 'inspira', 'transforma_en'],
            },
          },
          'required': ['id', 'source', 'target', 'relation'],
        },
      },
      'affinity_edges': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'source': {'type': 'string'},
            'target': {'type': 'string'},
            'weight': {'type': 'number'},
          },
          'required': ['source', 'target', 'weight'],
        },
      },
      'turning_point_candidates': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'node_id': {'type': 'string'},
            'evidence': {'type': 'string'},
          },
          'required': ['node_id', 'evidence'],
        },
      },
      'followup_questions': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': [
      'nodes',
      'edges',
      'affinity_edges',
      'turning_point_candidates',
      'followup_questions',
    ],
  },
};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/tool_schema_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/engine/tool_schema.dart test/engine/tool_schema_test.dart
git commit -m "feat: add emit_creative_graph tool schema"
```

---

## Task 9: System prompt

**Files:**
- Create: `lib/engine/system_prompt.dart`
- Test: `test/engine/system_prompt_test.dart`

**Interfaces:**
- Produces: `const String creativeGraphSystemPrompt`.

- [ ] **Step 1: Write the failing test**

```dart
// test/engine/system_prompt_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/system_prompt.dart';

void main() {
  group('creativeGraphSystemPrompt', () {
    test('covers the node types, edge relations and turning point rules', () {
      expect(creativeGraphSystemPrompt, contains('Fuente'));
      expect(creativeGraphSystemPrompt, contains('Concepto'));
      expect(creativeGraphSystemPrompt, contains('desencadena'));
      expect(creativeGraphSystemPrompt, contains('deriva_de'));
      expect(creativeGraphSystemPrompt, contains('inspira'));
      expect(creativeGraphSystemPrompt, contains('transforma_en'));
      expect(creativeGraphSystemPrompt, contains('acyclic'));
      expect(creativeGraphSystemPrompt, contains('emit_creative_graph'));
    });

    test('instructs the model to preserve the user\'s own language', () {
      expect(creativeGraphSystemPrompt.toLowerCase(),
          contains('the user\'s language'.toLowerCase()));
    });

    test('instructs the model not to invent turning points or dates', () {
      final lower = creativeGraphSystemPrompt.toLowerCase();
      expect(lower, contains('propose no candidates'));
      expect(lower, contains('never invent dates'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/system_prompt_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/engine/system_prompt.dart
const String creativeGraphSystemPrompt = '''
You are the generation engine of "Genealogía Creativa", an app for solo
creators who want to see how their ideas actually evolved. Nothing is 100%
original: ideas are remixes of existing sources, passed through a personal
filter of experiences, obsessions and knowledge. Innovation happens when
sources from unrelated domains collide.

Read the user's input (a devlog, a retro, a voice-note transcript, a messy
brain dump) and extract one shared graph, then call the emit_creative_graph
tool with it. Think through the timeline before you emit anything.

## How to model the graph

There are two node types:
- Fuente (S): an external input, such as a book, paper, documentation page,
  bug, performance bottleneck, conversation, class, song, screenshot,
  person, or real-world observation. Fuentes only point into Concepto nodes,
  never into each other, because a source influences an idea, not another
  source.
- Concepto (C): the idea at a specific moment of its evolution. Split a
  concept into separate C nodes whenever its approach meaningfully changed.

Edges are directed and follow time: S->C or C->C. Use "desencadena" when a
source or state provokes a change, "deriva_de" for incremental evolution,
"inspira" for a looser influence, and "transforma_en" when an idea becomes
something qualitatively different. The lineage must be acyclic. If the user
describes going back to an old approach, model it as a new C node that
deriva_de the old one, not as a loop.

Give every node a cluster: a short domain tag in kebab-case (for example
arquitectura-software, vida-universitaria, musica, biologia). Choose them so
that two genuinely different domains never share a tag, and don't split one
domain into synonyms.

## Turning points (puntos de inflexión)

A turning point is a node where sources from previously unconnected
clusters converge (two or more incoming Fuentes with different clusters),
and the flow changes direction afterward (the nodes that follow live in a
different cluster or approach than the ones before it). Propose candidates
only where you can write the evidence as the user would recognize it,
naming what collided and what changed afterward. If nothing in the input
qualifies, propose no candidates. An honest graph without turning points is
better than an invented epiphany.

## The two views

Jardín Digital: group every node into clusters and link related nodes with
an affinity_weight from 0 to 1 in affinity_edges. Include loose fragments
that never led anywhere.

Árbol Genealógico: the directed lineage. Level 1 referentes (people and
works that shaped the user directly) are Fuente nodes with level: 1; suggest
their own referentes as Fuente nodes with level: 2 and referente_of pointing
at the level-1 node, but only real, verifiable influences you are confident
about, marked origin: "sugerido" with a confidence between 0 and 1 — suggest
fewer rather than guess, and never suggest anything about the user's private
life. Do not emit a root "TÚ" node; the app adds it. The concept lineage (the
C nodes and their turning points) hangs from the Fuentes that fed it via the
normal S->C/C->C edges above — never as a Fuente-to-Fuente edge.

## Grounding rules

- Mark every node origin: "usuario" if it comes from the input and
  origin: "sugerido" if you added it, with a confidence for suggested nodes.
- Write labels and descriptions in the user's language and vocabulary. If
  they say "el cuello de botella en el build", don't rewrite it as
  "performance degradation".
- Use timestamps only when the input gives them or clearly implies an order.
  Otherwise use null plus sequence (a relative integer order), and never
  invent dates.
- If the input is too thin to build a meaningful tree, still build the
  garden and put one or two questions in followup_questions that would
  unlock the lineage — for example, ask who taught them this, or what they
  were reading when it changed.

Call emit_creative_graph exactly once with the full graph.
''';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/system_prompt_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/engine/system_prompt.dart test/engine/system_prompt_test.dart
git commit -m "feat: add generation engine system prompt"
```

---

## Task 10: Graph parser

**Files:**
- Create: `lib/engine/graph_parser.dart`
- Test: `test/engine/graph_parser_test.dart`

**Interfaces:**
- Consumes: `Node`, `LineageEdge`, `AffinityEdge`, `TurningPoint`, `CreativeGraph` (Tasks 2–6).
- Produces: `class GraphParseException implements Exception { final String message; const GraphParseException(this.message); }`, `CreativeGraph parseCreativeGraph(Map<String, dynamic> args)`. Later tasks (11, 14) call `parseCreativeGraph` and catch `GraphParseException`.

- [ ] **Step 1: Write the failing test**

```dart
// test/engine/graph_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/graph_parser.dart';
import 'package:creative/models/node.dart';

Map<String, dynamic> _validArgs() => {
      'nodes': [
        {
          'id': 's1',
          'type': 'fuente',
          'label': 'Charla de bases de datos',
          'description': 'd',
          'cluster': 'bases-de-datos',
          'origin': 'usuario',
        },
        {
          'id': 'c1',
          'type': 'concepto',
          'label': 'Cache manual',
          'description': 'd',
          'cluster': 'arquitectura-software',
          'origin': 'usuario',
        },
      ],
      'edges': [
        {'id': 'e1', 'source': 's1', 'target': 'c1', 'relation': 'desencadena'},
      ],
      'affinity_edges': [
        {'source': 's1', 'target': 'c1', 'weight': 0.6},
      ],
      'turning_point_candidates': [
        {'node_id': 'c1', 'evidence': 'evidencia'},
      ],
      'followup_questions': <String>[],
    };

void main() {
  group('parseCreativeGraph', () {
    test('parses a valid, fully-linked response', () {
      final graph = parseCreativeGraph(_validArgs());

      expect(graph.nodes, hasLength(2));
      expect(graph.edges, hasLength(1));
      expect(graph.affinityEdges, hasLength(1));
      expect(graph.turningPoints, hasLength(1));
      expect(graph.turningPoints.single.isVerified, isFalse);
    });

    test('throws GraphParseException when nodes is missing', () {
      final args = _validArgs()..remove('nodes');
      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('throws GraphParseException on a Fuente->Fuente lineage edge', () {
      final args = _validArgs();
      (args['nodes'] as List).add({
        'id': 's2',
        'type': 'fuente',
        'label': 'Otra fuente',
        'description': 'd',
        'cluster': 'musica',
        'origin': 'usuario',
      });
      (args['edges'] as List).add({
        'id': 'e2',
        'source': 's1',
        'target': 's2',
        'relation': 'inspira',
      });

      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('throws GraphParseException when an edge references an unknown node id', () {
      final args = _validArgs();
      (args['edges'] as List).add({
        'id': 'e2',
        'source': 'nope',
        'target': 'c1',
        'relation': 'inspira',
      });

      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('throws GraphParseException on a duplicate node id', () {
      final args = _validArgs();
      (args['nodes'] as List).add({
        'id': 's1',
        'type': 'fuente',
        'label': 'Duplicado',
        'description': 'd',
        'cluster': 'musica',
        'origin': 'usuario',
      });

      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('throws GraphParseException when a turning point candidate targets a Fuente', () {
      final args = _validArgs();
      (args['turning_point_candidates'] as List).add({
        'node_id': 's1',
        'evidence': 'evidencia inválida',
      });

      expect(() => parseCreativeGraph(args), throwsA(isA<GraphParseException>()));
    });

    test('defaults followup_questions to an empty list when absent', () {
      final args = _validArgs()..remove('followup_questions');
      final graph = parseCreativeGraph(args);
      expect(graph.followupQuestions, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/graph_parser_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/engine/graph_parser.dart
import '../models/node.dart';
import '../models/lineage_edge.dart';
import '../models/affinity_edge.dart';
import '../models/turning_point.dart';
import '../models/creative_graph.dart';

class GraphParseException implements Exception {
  const GraphParseException(this.message);
  final String message;

  @override
  String toString() => 'GraphParseException: $message';
}

CreativeGraph parseCreativeGraph(Map<String, dynamic> args) {
  try {
    final nodes = _parseList(args['nodes'], 'nodes')
        .asMap()
        .entries
        .map((e) => _wrapItem(e.key, 'nodes', () => Node.fromJson(e.value as Map<String, dynamic>)))
        .toList();

    final edges = _parseList(args['edges'], 'edges')
        .asMap()
        .entries
        .map((e) => _wrapItem(e.key, 'edges', () => LineageEdge.fromJson(e.value as Map<String, dynamic>)))
        .toList();

    final affinityEdges = _parseList(args['affinity_edges'] ?? const [], 'affinity_edges')
        .asMap()
        .entries
        .map((e) => _wrapItem(e.key, 'affinity_edges', () => AffinityEdge.fromJson(e.value as Map<String, dynamic>)))
        .toList();

    final turningPoints = _parseList(args['turning_point_candidates'] ?? const [], 'turning_point_candidates')
        .asMap()
        .entries
        .map((e) => _wrapItem(e.key, 'turning_point_candidates', () => TurningPoint.fromCandidateJson(e.value as Map<String, dynamic>)))
        .toList();

    final followupQuestions = _parseList(args['followup_questions'] ?? const [], 'followup_questions')
        .map((e) => e as String)
        .toList();

    final nodeIds = <String>{};
    for (final node in nodes) {
      if (!nodeIds.add(node.id)) {
        throw GraphParseException('id de nodo duplicado: ${node.id}');
      }
    }
    final nodesById = {for (final node in nodes) node.id: node};

    for (final edge in edges) {
      final source = nodesById[edge.source];
      final target = nodesById[edge.target];
      if (source == null) {
        throw GraphParseException('edge ${edge.id} referencia un nodo origen desconocido: ${edge.source}');
      }
      if (target == null) {
        throw GraphParseException('edge ${edge.id} referencia un nodo destino desconocido: ${edge.target}');
      }
      if (target.type != NodeType.concepto) {
        throw GraphParseException('edge ${edge.id} debe apuntar a un nodo concepto, no a ${edge.target}');
      }
    }

    for (final affinityEdge in affinityEdges) {
      if (!nodeIds.contains(affinityEdge.source)) {
        throw GraphParseException('affinity edge referencia un nodo origen desconocido: ${affinityEdge.source}');
      }
      if (!nodeIds.contains(affinityEdge.target)) {
        throw GraphParseException('affinity edge referencia un nodo destino desconocido: ${affinityEdge.target}');
      }
    }

    for (final turningPoint in turningPoints) {
      final node = nodesById[turningPoint.nodeId];
      if (node == null) {
        throw GraphParseException('turning point candidate referencia un nodo desconocido: ${turningPoint.nodeId}');
      }
      if (node.type != NodeType.concepto) {
        throw GraphParseException('turning point candidate debe ser un nodo concepto: ${turningPoint.nodeId}');
      }
    }

    return CreativeGraph(
      nodes: nodes,
      edges: edges,
      affinityEdges: affinityEdges,
      turningPoints: turningPoints,
      followupQuestions: followupQuestions,
    );
  } on GraphParseException {
    rethrow;
  } catch (e) {
    throw GraphParseException('formato inesperado: $e');
  }
}

List<dynamic> _parseList(dynamic value, String field) {
  if (value is List) return value;
  throw GraphParseException('se esperaba una lista en "$field"');
}

T _wrapItem<T>(int index, String field, T Function() parse) {
  try {
    return parse();
  } on GraphParseException {
    rethrow;
  } catch (e) {
    throw GraphParseException('elemento inválido en "$field" (posición $index): $e');
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/graph_parser_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/engine/graph_parser.dart test/engine/graph_parser_test.dart
git commit -m "feat: add graph parser with structural validation"
```

---

## Task 11: Graph verifier

**Files:**
- Create: `lib/engine/graph_verifier.dart`
- Test: `test/engine/graph_verifier_test.dart`

**Interfaces:**
- Consumes: `CreativeGraph`, `Node`, `NodeType`, `LineageEdge`, `TurningPoint` (Tasks 2, 3, 5, 6).
- Produces: `class CyclicGraphException implements Exception { final String message; const CyclicGraphException(this.message); }`, `CreativeGraph verifyGraph(CreativeGraph graph)`. Later Task 14 calls `verifyGraph` and catches `CyclicGraphException`.

- [ ] **Step 1: Write the failing test**

```dart
// test/engine/graph_verifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/graph_verifier.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/lineage_edge.dart';
import 'package:creative/models/turning_point.dart';

Node _fuente(String id, String cluster) => Node(
      id: id,
      type: NodeType.fuente,
      label: id,
      description: id,
      cluster: cluster,
      origin: NodeOrigin.usuario,
    );

Node _concepto(String id, String cluster) => Node(
      id: id,
      type: NodeType.concepto,
      label: id,
      description: id,
      cluster: cluster,
      origin: NodeOrigin.usuario,
    );

LineageEdge _edge(String id, String source, String target,
        [LineageRelation relation = LineageRelation.desencadena]) =>
    LineageEdge(id: id, source: source, target: target, relation: relation);

void main() {
  group('verifyGraph', () {
    test('throws CyclicGraphException when the lineage has a cycle', () {
      final graph = CreativeGraph(
        nodes: [_concepto('c1', 'a'), _concepto('c2', 'a')],
        edges: [
          _edge('e1', 'c1', 'c2', LineageRelation.derivaDe),
          _edge('e2', 'c2', 'c1', LineageRelation.derivaDe),
        ],
        affinityEdges: const [],
        turningPoints: const [],
        followupQuestions: const [],
      );

      expect(() => verifyGraph(graph), throwsA(isA<CyclicGraphException>()));
    });

    test('keeps a turning point candidate that converges and changes direction', () {
      final graph = CreativeGraph(
        nodes: [
          _fuente('s1', 'bases-de-datos'),
          _fuente('s2', 'musica'),
          _concepto('c1', 'arquitectura-software'),
          _concepto('c2', 'infraestructura-eventos'),
        ],
        edges: [
          _edge('e1', 's1', 'c1'),
          _edge('e2', 's2', 'c1'),
          _edge('e3', 'c1', 'c2', LineageRelation.transformaEn),
        ],
        affinityEdges: const [],
        turningPoints: [const TurningPoint(nodeId: 'c1', evidence: 'evidencia')],
        followupQuestions: const [],
      );

      final verified = verifyGraph(graph);

      expect(verified.turningPoints, hasLength(1));
      expect(verified.turningPoints.single.convergence, isTrue);
      expect(verified.turningPoints.single.directionChange, isTrue);
      expect(verified.turningPoints.single.isVerified, isTrue);
    });

    test('drops a candidate with only one incoming Fuente cluster (no convergence)', () {
      final graph = CreativeGraph(
        nodes: [
          _fuente('s1', 'bases-de-datos'),
          _concepto('c1', 'arquitectura-software'),
          _concepto('c2', 'infraestructura-eventos'),
        ],
        edges: [
          _edge('e1', 's1', 'c1'),
          _edge('e2', 'c1', 'c2', LineageRelation.transformaEn),
        ],
        affinityEdges: const [],
        turningPoints: [const TurningPoint(nodeId: 'c1', evidence: 'evidencia')],
        followupQuestions: const [],
      );

      final verified = verifyGraph(graph);
      expect(verified.turningPoints, isEmpty);
    });

    test('drops a candidate whose downstream cluster matches upstream (no direction change)', () {
      final graph = CreativeGraph(
        nodes: [
          _fuente('s1', 'bases-de-datos'),
          _fuente('s2', 'musica'),
          _concepto('c1', 'arquitectura-software'),
          _concepto('c2', 'arquitectura-software'),
        ],
        edges: [
          _edge('e1', 's1', 'c1'),
          _edge('e2', 's2', 'c1'),
          _edge('e3', 'c1', 'c2', LineageRelation.derivaDe),
        ],
        affinityEdges: const [],
        turningPoints: [const TurningPoint(nodeId: 'c1', evidence: 'evidencia')],
        followupQuestions: const [],
      );

      final verified = verifyGraph(graph);
      expect(verified.turningPoints, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/graph_verifier_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/engine/graph_verifier.dart
import 'dart:collection';

import '../models/creative_graph.dart';
import '../models/node.dart';
import '../models/turning_point.dart';

class CyclicGraphException implements Exception {
  const CyclicGraphException(this.message);
  final String message;

  @override
  String toString() => 'CyclicGraphException: $message';
}

CreativeGraph verifyGraph(CreativeGraph graph) {
  _assertAcyclic(graph);

  final nodesById = {for (final node in graph.nodes) node.id: node};
  final verified = graph.turningPoints
      .map((candidate) => _verifyTurningPoint(candidate, graph, nodesById))
      .where((tp) => tp.isVerified)
      .toList();

  return graph.copyWith(turningPoints: verified);
}

void _assertAcyclic(CreativeGraph graph) {
  final involvedIds = <String>{};
  for (final edge in graph.edges) {
    involvedIds.add(edge.source);
    involvedIds.add(edge.target);
  }

  final inDegree = {for (final id in involvedIds) id: 0};
  final adjacency = {for (final id in involvedIds) id: <String>[]};
  for (final edge in graph.edges) {
    adjacency[edge.source]!.add(edge.target);
    inDegree[edge.target] = (inDegree[edge.target] ?? 0) + 1;
  }

  final queue = Queue<String>()
    ..addAll(inDegree.entries.where((e) => e.value == 0).map((e) => e.key));

  var visited = 0;
  while (queue.isNotEmpty) {
    final id = queue.removeFirst();
    visited++;
    for (final next in adjacency[id] ?? const <String>[]) {
      inDegree[next] = inDegree[next]! - 1;
      if (inDegree[next] == 0) queue.add(next);
    }
  }

  if (visited != involvedIds.length) {
    throw const CyclicGraphException(
        'la línea de tiempo del linaje contiene un ciclo');
  }
}

TurningPoint _verifyTurningPoint(
  TurningPoint candidate,
  CreativeGraph graph,
  Map<String, Node> nodesById,
) {
  final incomingEdges =
      graph.edges.where((e) => e.target == candidate.nodeId);

  final incomingFuenteClusters = incomingEdges
      .map((e) => nodesById[e.source])
      .whereType<Node>()
      .where((n) => n.type == NodeType.fuente)
      .map((n) => n.cluster)
      .toSet();

  final upstreamClusters = <String>{...incomingFuenteClusters};
  for (final node in incomingEdges
      .map((e) => nodesById[e.source])
      .whereType<Node>()
      .where((n) => n.type == NodeType.concepto)) {
    upstreamClusters.add(node.cluster);
  }

  final downstreamClusters = graph.edges
      .where((e) => e.source == candidate.nodeId)
      .map((e) => nodesById[e.target])
      .whereType<Node>()
      .where((n) => n.type == NodeType.concepto)
      .map((n) => n.cluster)
      .toSet();

  final convergence = incomingFuenteClusters.length >= 2;
  final directionChange =
      downstreamClusters.any((cluster) => !upstreamClusters.contains(cluster));

  return candidate.copyWith(
    convergence: convergence,
    directionChange: directionChange,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/graph_verifier_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/engine/graph_verifier.dart test/engine/graph_verifier_test.dart
git commit -m "feat: add acyclicity and turning point verification"
```

---

## Task 12: Anthropic client

**Files:**
- Create: `lib/engine/graph_generation_client.dart`
- Create: `lib/engine/anthropic_client.dart`
- Test: `test/engine/anthropic_client_test.dart`

**Interfaces:**
- Consumes: `emitCreativeGraphToolSchema` (Task 8).
- Produces: `abstract class GraphGenerationClient { Future<Map<String, dynamic>> requestToolCall({required String apiKey, required String systemPrompt, required String userInput}); }`, `class AnthropicApiException implements Exception { final String message; const AnthropicApiException(this.message); }`, `class AnthropicClient implements GraphGenerationClient { AnthropicClient({http.Client? httpClient}); ... }`. Task 14 depends on `GraphGenerationClient` and `AnthropicApiException`.

- [ ] **Step 1: Write the failing test**

```dart
// test/engine/anthropic_client_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:creative/engine/anthropic_client.dart';
import 'package:creative/engine/graph_generation_client.dart';

void main() {
  group('AnthropicClient', () {
    test('returns the tool_use input map on a successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
        expect(request.headers['x-api-key'], 'test-key');
        expect(request.headers['anthropic-version'], isNotEmpty);

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'claude-sonnet-5');
        expect(body['tool_choice'], {'type': 'tool', 'name': 'emit_creative_graph'});

        return http.Response(
          jsonEncode({
            'content': [
              {
                'type': 'tool_use',
                'id': 'toolu_1',
                'name': 'emit_creative_graph',
                'input': {'nodes': [], 'edges': []},
              },
            ],
          }),
          200,
        );
      });

      final client = AnthropicClient(httpClient: mockClient);
      final result = await client.requestToolCall(
        apiKey: 'test-key',
        systemPrompt: 'system',
        userInput: 'input',
      );

      expect(result, {'nodes': [], 'edges': []});
    });

    test('throws AnthropicApiException on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "unauthorized"}', 401);
      });

      final client = AnthropicClient(httpClient: mockClient);

      expect(
        () => client.requestToolCall(
          apiKey: 'bad-key',
          systemPrompt: 'system',
          userInput: 'input',
        ),
        throwsA(isA<AnthropicApiException>()),
      );
    });

    test('throws AnthropicApiException when no tool_use block is returned', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'no debería responder así'},
            ],
          }),
          200,
        );
      });

      final client = AnthropicClient(httpClient: mockClient);

      expect(
        () => client.requestToolCall(
          apiKey: 'test-key',
          systemPrompt: 'system',
          userInput: 'input',
        ),
        throwsA(isA<AnthropicApiException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/anthropic_client_test.dart`
Expected: FAIL — files do not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/engine/graph_generation_client.dart
abstract class GraphGenerationClient {
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  });
}

class AnthropicApiException implements Exception {
  const AnthropicApiException(this.message);
  final String message;

  @override
  String toString() => 'AnthropicApiException: $message';
}
```

```dart
// lib/engine/anthropic_client.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'graph_generation_client.dart';
import 'tool_schema.dart';

class AnthropicClient implements GraphGenerationClient {
  AnthropicClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-5';
  static const _anthropicVersion = '2023-06-01';
  static const _maxTokens = 8192;

  @override
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _anthropicVersion,
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': _maxTokens,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userInput},
        ],
        'tools': [emitCreativeGraphToolSchema],
        'tool_choice': {'type': 'tool', 'name': 'emit_creative_graph'},
      }),
    );

    if (response.statusCode != 200) {
      throw AnthropicApiException(
          'Anthropic API devolvió ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'] as List<dynamic>?;
    if (content == null) {
      throw const AnthropicApiException('respuesta sin contenido');
    }

    final toolUse = content
        .map((block) => block as Map<String, dynamic>)
        .where((block) => block['type'] == 'tool_use')
        .cast<Map<String, dynamic>?>()
        .firstWhere((_) => true, orElse: () => null);

    if (toolUse == null) {
      throw const AnthropicApiException(
          'el modelo no llamó a emit_creative_graph');
    }

    return toolUse['input'] as Map<String, dynamic>;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/anthropic_client_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/engine/graph_generation_client.dart lib/engine/anthropic_client.dart test/engine/anthropic_client_test.dart
git commit -m "feat: add Anthropic Messages API client"
```

---

## Task 13: API key store

**Files:**
- Create: `lib/storage/api_key_store.dart`
- Test: `test/storage/api_key_store_test.dart`

**Interfaces:**
- Produces: `abstract class ApiKeyStore { Future<String?> getApiKey(); Future<void> setApiKey(String key); Future<void> clearApiKey(); }`, `class SecureApiKeyStore implements ApiKeyStore { const SecureApiKeyStore({FlutterSecureStorage storage = const FlutterSecureStorage()}); ... }`. Task 16 (app wiring), Task 18 (InputScreen), Task 21 (ApiKeyScreen) depend on `ApiKeyStore`.

- [ ] **Step 1: Write the failing test**

```dart
// test/storage/api_key_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:creative/storage/api_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform({});
  });

  group('SecureApiKeyStore', () {
    test('getApiKey returns null when nothing is stored', () async {
      const store = SecureApiKeyStore();
      expect(await store.getApiKey(), isNull);
    });

    test('setApiKey then getApiKey returns the stored key', () async {
      const store = SecureApiKeyStore();
      await store.setApiKey('sk-ant-test');
      expect(await store.getApiKey(), 'sk-ant-test');
    });

    test('clearApiKey removes the stored key', () async {
      const store = SecureApiKeyStore();
      await store.setApiKey('sk-ant-test');
      await store.clearApiKey();
      expect(await store.getApiKey(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/storage/api_key_store_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/storage/api_key_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ApiKeyStore {
  Future<String?> getApiKey();
  Future<void> setApiKey(String key);
  Future<void> clearApiKey();
}

class SecureApiKeyStore implements ApiKeyStore {
  const SecureApiKeyStore({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;
  static const _key = 'anthropic_api_key';

  @override
  Future<String?> getApiKey() => storage.read(key: _key);

  @override
  Future<void> setApiKey(String key) => storage.write(key: _key, value: key);

  @override
  Future<void> clearApiKey() => storage.delete(key: _key);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/storage/api_key_store_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/storage/api_key_store.dart test/storage/api_key_store_test.dart
git commit -m "feat: add secure API key store"
```

---

## Task 14: Generation engine

**Files:**
- Create: `lib/engine/graph_generator.dart`
- Create: `lib/engine/generation_engine.dart`
- Create: `test/helpers/fakes.dart`
- Test: `test/engine/generation_engine_test.dart`

**Interfaces:**
- Consumes: `GraphGenerationClient`, `AnthropicApiException` (Task 12), `ApiKeyStore` (Task 13), `parseCreativeGraph`, `GraphParseException` (Task 10), `verifyGraph`, `CyclicGraphException` (Task 11), `GraphSession` (Task 7).
- Produces: `abstract class GraphGenerator { Future<GraphSession> generate(String rawInput); }`, `class GenerationFailedException implements Exception { final String message; const GenerationFailedException(this.message); }`, `class GenerationEngine implements GraphGenerator { GenerationEngine({required GraphGenerationClient client, required ApiKeyStore apiKeyStore}); }`. Also produces reusable test doubles in `test/helpers/fakes.dart`: `class FakeApiKeyStore implements ApiKeyStore` and `class FakeGraphGenerationClient implements GraphGenerationClient` (constructed with a `List<Map<String, dynamic> Function()>` of responses to return in order, or a fixed error to throw) — later UI tasks (18, 21) add `FakeGraphGenerator` and `FakeSessionStore` to this same file.

- [ ] **Step 1: Write the test helpers and the failing test**

```dart
// test/helpers/fakes.dart
import 'package:creative/engine/graph_generation_client.dart';
import 'package:creative/storage/api_key_store.dart';

class FakeApiKeyStore implements ApiKeyStore {
  FakeApiKeyStore([this._key]);

  String? _key;

  @override
  Future<String?> getApiKey() async => _key;

  @override
  Future<void> setApiKey(String key) async => _key = key;

  @override
  Future<void> clearApiKey() async => _key = null;
}

class FakeGraphGenerationClient implements GraphGenerationClient {
  FakeGraphGenerationClient(this._responses);

  final List<Map<String, dynamic> Function()> _responses;
  var _callCount = 0;

  int get callCount => _callCount;

  @override
  Future<Map<String, dynamic>> requestToolCall({
    required String apiKey,
    required String systemPrompt,
    required String userInput,
  }) async {
    final index = _callCount;
    _callCount++;
    return _responses[index]();
  }
}
```

```dart
// test/engine/generation_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/generation_engine.dart';
import 'package:creative/engine/graph_generator.dart';

import '../helpers/fakes.dart';

Map<String, dynamic> _validArgs() => {
      'nodes': [
        {
          'id': 's1',
          'type': 'fuente',
          'label': 'Charla',
          'description': 'd',
          'cluster': 'bases-de-datos',
          'origin': 'usuario',
        },
        {
          'id': 'c1',
          'type': 'concepto',
          'label': 'Cache manual',
          'description': 'd',
          'cluster': 'arquitectura-software',
          'origin': 'usuario',
        },
      ],
      'edges': [
        {'id': 'e1', 'source': 's1', 'target': 'c1', 'relation': 'desencadena'},
      ],
      'affinity_edges': <Map<String, dynamic>>[],
      'turning_point_candidates': <Map<String, dynamic>>[],
      'followup_questions': <String>[],
    };

Map<String, dynamic> _cyclicArgs() => {
      'nodes': [
        {
          'id': 'c1',
          'type': 'concepto',
          'label': 'a',
          'description': 'd',
          'cluster': 'x',
          'origin': 'usuario',
        },
        {
          'id': 'c2',
          'type': 'concepto',
          'label': 'b',
          'description': 'd',
          'cluster': 'x',
          'origin': 'usuario',
        },
      ],
      'edges': [
        {'id': 'e1', 'source': 'c1', 'target': 'c2', 'relation': 'deriva_de'},
        {'id': 'e2', 'source': 'c2', 'target': 'c1', 'relation': 'deriva_de'},
      ],
      'affinity_edges': <Map<String, dynamic>>[],
      'turning_point_candidates': <Map<String, dynamic>>[],
      'followup_questions': <String>[],
    };

void main() {
  group('GenerationEngine', () {
    test('returns a saved GraphSession on the first successful attempt', () async {
      final apiKeyStore = FakeApiKeyStore('sk-ant-test');
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      final session = await engine.generate('input de prueba');

      expect(session.rawInput, 'input de prueba');
      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 1);
    });

    test('retries once after a malformed response, then succeeds', () async {
      final apiKeyStore = FakeApiKeyStore('sk-ant-test');
      final client = FakeGraphGenerationClient([
        () => {'nodes': 'not-a-list'},
        _validArgs,
      ]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      final session = await engine.generate('input de prueba');

      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 2);
    });

    test('throws GenerationFailedException after two malformed responses', () async {
      final apiKeyStore = FakeApiKeyStore('sk-ant-test');
      final client = FakeGraphGenerationClient([
        () => {'nodes': 'not-a-list'},
        () => {'nodes': 'still-not-a-list'},
      ]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      expect(
        () => engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>()),
      );
    });

    test('throws GenerationFailedException on a cyclic lineage without retry', () async {
      final apiKeyStore = FakeApiKeyStore('sk-ant-test');
      final client = FakeGraphGenerationClient([_cyclicArgs, _validArgs]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      final session = await engine.generate('input de prueba');

      // The cycle is rejected and retried once, same as a parse failure.
      expect(session.graph.nodes, hasLength(2));
      expect(client.callCount, 2);
    });

    test('throws GenerationFailedException when no API key is configured', () async {
      final apiKeyStore = FakeApiKeyStore();
      final client = FakeGraphGenerationClient([_validArgs]);
      final GraphGenerator engine =
          GenerationEngine(client: client, apiKeyStore: apiKeyStore);

      expect(
        () => engine.generate('input de prueba'),
        throwsA(isA<GenerationFailedException>()),
      );
      expect(client.callCount, 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/generation_engine_test.dart`
Expected: FAIL — files do not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/engine/graph_generator.dart
import '../models/session.dart';

abstract class GraphGenerator {
  Future<GraphSession> generate(String rawInput);
}

class GenerationFailedException implements Exception {
  const GenerationFailedException(this.message);
  final String message;

  @override
  String toString() => 'GenerationFailedException: $message';
}
```

```dart
// lib/engine/generation_engine.dart
import '../models/creative_graph.dart';
import '../models/session.dart';
import '../storage/api_key_store.dart';
import 'graph_generation_client.dart';
import 'graph_generator.dart';
import 'graph_parser.dart';
import 'graph_verifier.dart';
import 'system_prompt.dart';

class GenerationEngine implements GraphGenerator {
  GenerationEngine({
    required GraphGenerationClient client,
    required ApiKeyStore apiKeyStore,
  })  : _client = client,
        _apiKeyStore = apiKeyStore;

  final GraphGenerationClient _client;
  final ApiKeyStore _apiKeyStore;

  static const _maxAttempts = 2;

  @override
  Future<GraphSession> generate(String rawInput) async {
    final apiKey = await _apiKeyStore.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const GenerationFailedException(
          'no hay una clave de API de Anthropic configurada');
    }

    CreativeGraph? verifiedGraph;
    Object? lastError;

    for (var attempt = 0; attempt < _maxAttempts && verifiedGraph == null; attempt++) {
      try {
        final rawArgs = await _client.requestToolCall(
          apiKey: apiKey,
          systemPrompt: creativeGraphSystemPrompt,
          userInput: rawInput,
        );
        final parsed = parseCreativeGraph(rawArgs);
        verifiedGraph = verifyGraph(parsed);
      } on GraphParseException catch (e) {
        lastError = e;
      } on CyclicGraphException catch (e) {
        lastError = e;
      }
    }

    if (verifiedGraph == null) {
      throw GenerationFailedException('no se pudo generar el grafo: $lastError');
    }

    return GraphSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      rawInput: rawInput,
      graph: verifiedGraph,
      createdAt: DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/generation_engine_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/engine/graph_generator.dart lib/engine/generation_engine.dart test/helpers/fakes.dart test/engine/generation_engine_test.dart
git commit -m "feat: add generation engine orchestration with retry"
```

---

## Task 15: Session store

**Files:**
- Create: `lib/storage/session_store.dart`
- Test: `test/storage/session_store_test.dart`

**Interfaces:**
- Consumes: `GraphSession` (Task 7).
- Produces: `abstract class SessionStore { Future<List<GraphSession>> listSessions(); Future<void> saveSession(GraphSession session); Future<void> deleteSession(String id); }`, `class LocalSessionStore implements SessionStore { LocalSessionStore(SharedPreferences prefs); }`. Task 16 (app wiring), Task 19 (SessionListScreen), Task 18 (InputScreen) depend on `SessionStore`.

- [ ] **Step 1: Write the failing test**

```dart
// test/storage/session_store_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/storage/session_store_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/storage/session_store.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/storage/session_store_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/storage/session_store.dart test/storage/session_store_test.dart
git commit -m "feat: add local session store backed by shared_preferences"
```

---

## Task 16: App scaffolding — replace the counter demo

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart` (replace entirely)
- Modify: `test/widget_test.dart` (replace entirely)

**Interfaces:**
- Consumes: `SessionStore` (Task 15), `ApiKeyStore` (Task 13), `GraphGenerator` (Task 14).
- Produces: `class CreativeApp extends StatelessWidget { const CreativeApp({required SessionStore sessionStore, required ApiKeyStore apiKeyStore, required GraphGenerator generator}); }`. `CreativeApp.home` is a placeholder `Scaffold` with the text `'Genealogía Creativa'` for now — Task 19 replaces it with the real `SessionListScreen`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/app.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('CreativeApp renders its home screen', (tester) async {
    await tester.pumpWidget(CreativeApp(
      sessionStore: FakeSessionStore(),
      apiKeyStore: FakeApiKeyStore(),
      generator: FakeGraphGenerator(),
    ));

    expect(find.text('Genealogía Creativa'), findsWidgets);
  });
}
```

Add the two new fakes this test needs to the shared fakes file:

```dart
// Append to test/helpers/fakes.dart
import 'package:creative/engine/graph_generator.dart';
import 'package:creative/models/session.dart';
import 'package:creative/storage/session_store.dart';

class FakeGraphGenerator implements GraphGenerator {
  FakeGraphGenerator([this._onGenerate]);

  final Future<GraphSession> Function(String rawInput)? _onGenerate;

  @override
  Future<GraphSession> generate(String rawInput) {
    if (_onGenerate != null) return _onGenerate(rawInput);
    throw UnimplementedError('FakeGraphGenerator has no _onGenerate handler');
  }
}

class FakeSessionStore implements SessionStore {
  FakeSessionStore([List<GraphSession>? initial]) : sessions = initial ?? [];

  final List<GraphSession> sessions;

  @override
  Future<List<GraphSession>> listSessions() async =>
      List.unmodifiable(sessions);

  @override
  Future<void> saveSession(GraphSession session) async {
    sessions.insert(0, session);
  }

  @override
  Future<void> deleteSession(String id) async {
    sessions.removeWhere((s) => s.id == id);
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `lib/app.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/app.dart
import 'package:flutter/material.dart';

import 'engine/graph_generator.dart';
import 'storage/api_key_store.dart';
import 'storage/session_store.dart';

class CreativeApp extends StatelessWidget {
  const CreativeApp({
    super.key,
    required this.sessionStore,
    required this.apiKeyStore,
    required this.generator,
  });

  final SessionStore sessionStore;
  final ApiKeyStore apiKeyStore;
  final GraphGenerator generator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Genealogía Creativa',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const Scaffold(
        body: Center(child: Text('Genealogía Creativa')),
      ),
    );
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'engine/anthropic_client.dart';
import 'engine/generation_engine.dart';
import 'storage/api_key_store.dart';
import 'storage/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  const apiKeyStore = SecureApiKeyStore();

  runApp(CreativeApp(
    sessionStore: LocalSessionStore(prefs),
    apiKeyStore: apiKeyStore,
    generator: GenerationEngine(
      client: AnthropicClient(),
      apiKeyStore: apiKeyStore,
    ),
  ));
}
```

Delete the old counter test fixture content that referenced `MyApp` — this file is fully replaced by Step 1's content above.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart lib/main.dart test/widget_test.dart test/helpers/fakes.dart
git commit -m "feat: replace counter demo with CreativeApp scaffolding"
```

---

## Task 17: Node detail sheet

**Files:**
- Create: `lib/ui/graph/node_detail_sheet.dart`
- Test: `test/ui/node_detail_sheet_test.dart`

**Interfaces:**
- Consumes: `Node` (Task 2).
- Produces: `class NodeDetailSheet extends StatelessWidget { const NodeDetailSheet({required Node node}); }`. Tasks 22 and 23 open this via `showModalBottomSheet`.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/node_detail_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/node.dart';
import 'package:creative/ui/graph/node_detail_sheet.dart';

void main() {
  testWidgets('shows label, description, cluster and origin', (tester) async {
    const node = Node(
      id: 'c1',
      type: NodeType.concepto,
      label: 'Arquitectura hexagonal',
      description: 'Separar el dominio de la infraestructura',
      cluster: 'arquitectura-software',
      origin: NodeOrigin.usuario,
    );

    await tester.pumpWidget(const MaterialApp(
      home: NodeDetailSheet(node: node),
    ));

    expect(find.text('Arquitectura hexagonal'), findsOneWidget);
    expect(find.text('Separar el dominio de la infraestructura'), findsOneWidget);
    expect(find.textContaining('arquitectura-software'), findsOneWidget);
  });

  testWidgets('shows confidence for a suggested node', (tester) async {
    const node = Node(
      id: 's2',
      type: NodeType.fuente,
      label: 'Christopher Alexander',
      description: 'Patrones de diseño arquitectónico',
      cluster: 'arquitectura-software',
      origin: NodeOrigin.sugerido,
      confidence: 0.6,
      level: 2,
    );

    await tester.pumpWidget(const MaterialApp(
      home: NodeDetailSheet(node: node),
    ));

    expect(find.textContaining('sugerido'), findsOneWidget);
    expect(find.textContaining('60%'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/node_detail_sheet_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/graph/node_detail_sheet.dart
import 'package:flutter/material.dart';

import '../../models/node.dart';

class NodeDetailSheet extends StatelessWidget {
  const NodeDetailSheet({super.key, required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(node.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(node.cluster)),
                Chip(
                  label: Text(
                    node.origin == NodeOrigin.usuario ? 'usuario' : 'sugerido',
                  ),
                ),
                if (node.confidence != null)
                  Chip(
                    label: Text(
                      'confianza ${(node.confidence! * 100).round()}%',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/node_detail_sheet_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/graph/node_detail_sheet.dart test/ui/node_detail_sheet_test.dart
git commit -m "feat: add node detail sheet"
```

---

## Task 18: API key screen

**Files:**
- Create: `lib/ui/settings/api_key_screen.dart`
- Test: `test/ui/api_key_screen_test.dart`

**Interfaces:**
- Consumes: `ApiKeyStore` (Task 13), `FakeApiKeyStore` (Task 14's fakes file).
- Produces: `class ApiKeyScreen extends StatefulWidget { const ApiKeyScreen({required ApiKeyStore apiKeyStore}); }`. Task 19 (SessionListScreen) pushes this screen.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/api_key_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/settings/api_key_screen.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('prefills the existing key and saves a new one', (tester) async {
    final store = FakeApiKeyStore('sk-ant-old');

    await tester.pumpWidget(MaterialApp(
      home: ApiKeyScreen(apiKeyStore: store),
    ));
    await tester.pumpAndSettle();

    expect(find.text('sk-ant-old'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sk-ant-new');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(await store.getApiKey(), 'sk-ant-new');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/api_key_screen_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/settings/api_key_screen.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/api_key_screen_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/api_key_screen.dart test/ui/api_key_screen_test.dart
git commit -m "feat: add API key settings screen"
```

---

## Task 19: Input screen

**Files:**
- Create: `lib/ui/input/input_screen.dart`
- Test: `test/ui/input_screen_test.dart`

**Interfaces:**
- Consumes: `GraphGenerator`, `GenerationFailedException` (Task 14), `SessionStore` (Task 15), `GraphSession` (Task 7), `FakeGraphGenerator`, `FakeSessionStore` (Task 16's fakes file).
- Produces: `class InputScreen extends StatefulWidget { const InputScreen({required GraphGenerator generator, required SessionStore sessionStore}); }`. On success it saves the session and calls `Navigator.pop(context, session)`. Task 19 (SessionListScreen) pushes this screen and awaits the popped `GraphSession?`.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/input_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/graph_generator.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/session.dart';
import 'package:creative/ui/input/input_screen.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('generates a graph and pops with the new session', (tester) async {
    final sessionStore = FakeSessionStore();
    final generator = FakeGraphGenerator((rawInput) async => GraphSession(
          id: '1',
          rawInput: rawInput,
          graph: const CreativeGraph(
            nodes: [],
            edges: [],
            affinityEdges: [],
            turningPoints: [],
            followupQuestions: [],
          ),
          createdAt: DateTime.utc(2026, 9, 21),
        ));

    GraphSession? poppedSession;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            poppedSession = await Navigator.of(context).push<GraphSession>(
              MaterialPageRoute(
                builder: (_) => InputScreen(
                  generator: generator,
                  sessionStore: sessionStore,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hoy arreglé un bug');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Generar'));
    await tester.pumpAndSettle();

    expect(poppedSession?.rawInput, 'hoy arreglé un bug');
    expect(sessionStore.sessions, hasLength(1));
  });

  testWidgets('shows an error banner when generation fails', (tester) async {
    final sessionStore = FakeSessionStore();
    final generator = FakeGraphGenerator(
      (rawInput) async => throw const GenerationFailedException('sin clave de API'),
    );

    await tester.pumpWidget(MaterialApp(
      home: InputScreen(generator: generator, sessionStore: sessionStore),
    ));

    await tester.enterText(find.byType(TextField), 'algo');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Generar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('sin clave de API'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/input_screen_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/input/input_screen.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/input_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/input/input_screen.dart test/ui/input_screen_test.dart
git commit -m "feat: add input screen with generation error handling"
```

---

## Task 20: Session list screen and wiring it into the app

**Files:**
- Create: `lib/ui/sessions/session_list_screen.dart`
- Modify: `lib/app.dart`
- Test: `test/ui/session_list_screen_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `SessionStore`, `GraphSession` (Task 15, 7), `ApiKeyStore` (Task 13), `GraphGenerator` (Task 14), `InputScreen` (Task 19), `ApiKeyScreen` (Task 18).
- Produces: `class SessionListScreen extends StatefulWidget { const SessionListScreen({required SessionStore sessionStore, required ApiKeyStore apiKeyStore, required GraphGenerator generator}); }`. `CreativeApp.home` becomes this screen.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/session_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/session.dart';
import 'package:creative/ui/sessions/session_list_screen.dart';

import '../helpers/fakes.dart';

GraphSession _session(String id) => GraphSession(
      id: id,
      rawInput: 'un devlog sobre $id',
      graph: const CreativeGraph(
        nodes: [],
        edges: [],
        affinityEdges: [],
        turningPoints: [],
        followupQuestions: [],
      ),
      createdAt: DateTime.utc(2026, 9, 21),
    );

void main() {
  testWidgets('shows an empty state with no sessions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SessionListScreen(
        sessionStore: FakeSessionStore(),
        apiKeyStore: FakeApiKeyStore(),
        generator: FakeGraphGenerator(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aún no tienes sesiones'), findsOneWidget);
  });

  testWidgets('lists existing sessions by their input snippet', (tester) async {
    final store = FakeSessionStore([_session('1'), _session('2')]);

    await tester.pumpWidget(MaterialApp(
      home: SessionListScreen(
        sessionStore: store,
        apiKeyStore: FakeApiKeyStore(),
        generator: FakeGraphGenerator(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('un devlog sobre 1'), findsOneWidget);
    expect(find.textContaining('un devlog sobre 2'), findsOneWidget);
  });
}
```

Update the app smoke test now that the real home screen exists:

```dart
// test/widget_test.dart (replace contents)
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/app.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('CreativeApp shows the session list as its home screen', (tester) async {
    await tester.pumpWidget(CreativeApp(
      sessionStore: FakeSessionStore(),
      apiKeyStore: FakeApiKeyStore(),
      generator: FakeGraphGenerator(),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aún no tienes sesiones'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/session_list_screen_test.dart test/widget_test.dart`
Expected: FAIL — `lib/ui/sessions/session_list_screen.dart` does not exist; `test/widget_test.dart` still expects the old placeholder text.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/sessions/session_list_screen.dart
import 'package:flutter/material.dart';

import '../../engine/graph_generator.dart';
import '../../models/session.dart';
import '../../storage/api_key_store.dart';
import '../../storage/session_store.dart';
import '../graph/graph_view_screen.dart';
import '../input/input_screen.dart';
import '../settings/api_key_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({
    super.key,
    required this.sessionStore,
    required this.apiKeyStore,
    required this.generator,
  });

  final SessionStore sessionStore;
  final ApiKeyStore apiKeyStore;
  final GraphGenerator generator;

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  List<GraphSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await widget.sessionStore.listSessions();
    if (mounted) setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _openNewSession() async {
    final session = await Navigator.of(context).push<GraphSession>(
      MaterialPageRoute(
        builder: (_) => InputScreen(
          generator: widget.generator,
          sessionStore: widget.sessionStore,
        ),
      ),
    );
    if (session != null) {
      setState(() => _sessions = [session, ..._sessions]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Genealogía Creativa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'Clave de API',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ApiKeyScreen(apiKeyStore: widget.apiKeyStore),
            )),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('Aún no tienes sesiones. Crea una nueva.'))
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final snippet = session.rawInput.length > 80
                        ? '${session.rawInput.substring(0, 80)}…'
                        : session.rawInput;
                    return ListTile(
                      title: Text(snippet),
                      subtitle: Text(session.createdAt.toLocal().toString()),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GraphViewScreen(session: session),
                      )),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewSession,
        icon: const Icon(Icons.add),
        label: const Text('Nueva sesión'),
      ),
    );
  }
}
```

```dart
// lib/app.dart (replace contents)
import 'package:flutter/material.dart';

import 'engine/graph_generator.dart';
import 'storage/api_key_store.dart';
import 'storage/session_store.dart';
import 'ui/sessions/session_list_screen.dart';

class CreativeApp extends StatelessWidget {
  const CreativeApp({
    super.key,
    required this.sessionStore,
    required this.apiKeyStore,
    required this.generator,
  });

  final SessionStore sessionStore;
  final ApiKeyStore apiKeyStore;
  final GraphGenerator generator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Genealogía Creativa',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: SessionListScreen(
        sessionStore: sessionStore,
        apiKeyStore: apiKeyStore,
        generator: generator,
      ),
    );
  }
}
```

Note: this task references `GraphViewScreen`, built in Task 24. Create a minimal placeholder now so this task compiles and its tests pass on their own:

```dart
// lib/ui/graph/graph_view_screen.dart (placeholder, replaced in Task 24)
import 'package:flutter/material.dart';

import '../../models/session.dart';

class GraphViewScreen extends StatelessWidget {
  const GraphViewScreen({super.key, required this.session});

  final GraphSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(session.rawInput)),
      body: const Center(child: Text('TODO')),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/session_list_screen_test.dart test/widget_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/sessions/session_list_screen.dart lib/ui/graph/graph_view_screen.dart lib/app.dart test/ui/session_list_screen_test.dart test/widget_test.dart
git commit -m "feat: add session list screen as the app home"
```

---

## Task 21: Turning point badge

**Files:**
- Create: `lib/ui/graph/turning_point_badge.dart`
- Test: `test/ui/turning_point_badge_test.dart`

**Interfaces:**
- Produces: `class TurningPointBadge extends StatelessWidget { const TurningPointBadge({required VoidCallback onTap}); }`. Task 23 (Árbol view) places this next to a verified turning-point node and wires `onTap` to show the evidence.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/turning_point_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/ui/graph/turning_point_badge.dart';

void main() {
  testWidgets('calls onTap when pressed', (tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TurningPointBadge(onTap: () => tapped = true),
      ),
    ));

    await tester.tap(find.byType(TurningPointBadge));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/turning_point_badge_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/graph/turning_point_badge.dart
import 'package:flutter/material.dart';

class TurningPointBadge extends StatelessWidget {
  const TurningPointBadge({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome, size: 14, color: Colors.black87),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/turning_point_badge_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/graph/turning_point_badge.dart test/ui/turning_point_badge_test.dart
git commit -m "feat: add turning point badge widget"
```

---

## Task 22: Jardín Digital view

**Files:**
- Create: `lib/ui/graph/jardin_digital_view.dart`
- Test: `test/ui/jardin_digital_view_test.dart`

**Interfaces:**
- Consumes: `CreativeGraph`, `Node` (Tasks 6, 2), `NodeDetailSheet` (Task 17), `graphview` package (`Graph`, `Node.Id`, `GraphView.builder`, `FruchtermanReingoldAlgorithm`, `FruchtermanReingoldConfiguration`).
- Produces: `class JardinDigitalView extends StatelessWidget { const JardinDigitalView({required CreativeGraph graph}); }`. Task 24 (GraphViewScreen) places this in one tab.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/jardin_digital_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/affinity_edge.dart';
import 'package:creative/ui/graph/jardin_digital_view.dart';

CreativeGraph _graph() => const CreativeGraph(
      nodes: [
        Node(
          id: 's1',
          type: NodeType.fuente,
          label: 'Charla de bases de datos',
          description: 'd',
          cluster: 'bases-de-datos',
          origin: NodeOrigin.usuario,
        ),
        Node(
          id: 'c1',
          type: NodeType.concepto,
          label: 'Cache manual',
          description: 'd',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.usuario,
        ),
        Node(
          id: 's2',
          type: NodeType.fuente,
          label: 'Fragmento suelto',
          description: 'd',
          cluster: 'musica',
          origin: NodeOrigin.usuario,
        ),
      ],
      edges: [],
      affinityEdges: [AffinityEdge(source: 's1', target: 'c1', weight: 0.5)],
      turningPoints: [],
      followupQuestions: [],
    );

void main() {
  testWidgets('renders every node label, including loose fragments', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: JardinDigitalView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Charla de bases de datos'), findsOneWidget);
    expect(find.text('Cache manual'), findsOneWidget);
    expect(find.text('Fragmento suelto'), findsOneWidget);
  });

  testWidgets('tapping a node opens its detail sheet', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: JardinDigitalView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cache manual'));
    await tester.pumpAndSettle();

    expect(find.text('d'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/jardin_digital_view_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/graph/jardin_digital_view.dart
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import 'node_detail_sheet.dart';

class JardinDigitalView extends StatelessWidget {
  const JardinDigitalView({super.key, required this.graph});

  final CreativeGraph graph;

  static const _clusterPalette = [
    Colors.teal,
    Colors.deepOrange,
    Colors.indigo,
    Colors.pink,
    Colors.green,
    Colors.amber,
    Colors.purple,
    Colors.cyan,
  ];

  Color _colorForCluster(String cluster) {
    final index = cluster.hashCode.abs() % _clusterPalette.length;
    return _clusterPalette[index];
  }

  @override
  Widget build(BuildContext context) {
    final nodesById = {for (final node in graph.nodes) node.id: node};
    final graphViewGraph = Graph();

    for (final node in graph.nodes) {
      graphViewGraph.addNode(Node.Id(node.id));
    }
    for (final edge in graph.affinityEdges) {
      graphViewGraph.addEdge(Node.Id(edge.source), Node.Id(edge.target));
    }

    final algorithm = FruchtermanReingoldAlgorithm(FruchtermanReingoldConfiguration());

    return GraphView.builder(
      graph: graphViewGraph,
      algorithm: algorithm,
      builder: (node) {
        final id = node.key!.value as String;
        final modelNode = nodesById[id]!;
        return _NodeChip(
          node: modelNode,
          color: _colorForCluster(modelNode.cluster),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => NodeDetailSheet(node: modelNode),
          ),
        );
      },
    );
  }
}

class _NodeChip extends StatelessWidget {
  const _NodeChip({required this.node, required this.color, required this.onTap});

  final model.Node node;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          node.label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/jardin_digital_view_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/graph/jardin_digital_view.dart test/ui/jardin_digital_view_test.dart
git commit -m "feat: add Jardin Digital force-directed view"
```

---

## Task 23: Árbol Genealógico view

**Files:**
- Create: `lib/ui/graph/arbol_genealogico_view.dart`
- Test: `test/ui/arbol_genealogico_view_test.dart`

**Interfaces:**
- Consumes: `CreativeGraph`, `Node`, `NodeType` (Tasks 6, 2), `NodeDetailSheet` (Task 17), `TurningPointBadge` (Task 21), `graphview` package (`Graph`, `Node.Id`, `GraphView.builder`, `SugiyamaAlgorithm`, `SugiyamaConfiguration`).
- Produces: `class ArbolGenealogicoView extends StatefulWidget { const ArbolGenealogicoView({required CreativeGraph graph}); }`. Task 24 (GraphViewScreen) places this in the other tab.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/arbol_genealogico_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/lineage_edge.dart';
import 'package:creative/models/turning_point.dart';
import 'package:creative/ui/graph/arbol_genealogico_view.dart';

CreativeGraph _graph() => const CreativeGraph(
      nodes: [
        Node(
          id: 'f1',
          type: NodeType.fuente,
          label: 'Robert C. Martin',
          description: 'd',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.usuario,
          level: 1,
        ),
        Node(
          id: 'f2',
          type: NodeType.fuente,
          label: 'Kent Beck',
          description: 'd',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.sugerido,
          confidence: 0.5,
          level: 2,
          referenteOf: 'f1',
        ),
        Node(
          id: 'c1',
          type: NodeType.concepto,
          label: 'Cache manual',
          description: 'd',
          cluster: 'arquitectura-software',
          origin: NodeOrigin.usuario,
        ),
      ],
      edges: [
        LineageEdge(id: 'e1', source: 'f1', target: 'c1', relation: LineageRelation.inspira),
      ],
      affinityEdges: [],
      turningPoints: [
        TurningPoint(
          nodeId: 'c1',
          evidence: 'convergencia real',
          convergence: true,
          directionChange: true,
        ),
      ],
      followupQuestions: [],
    );

void main() {
  testWidgets('renders the synthetic TU root and the referente tree', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ArbolGenealogicoView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TÚ'), findsOneWidget);
    expect(find.text('Robert C. Martin'), findsOneWidget);
    expect(find.text('Kent Beck'), findsOneWidget);
    expect(find.text('Cache manual'), findsOneWidget);
  });

  testWidgets('rejecting a sugerido node removes it from the tree', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ArbolGenealogicoView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kent Beck'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Kent Beck'), findsNothing);
  });

  testWidgets('tapping the turning point badge shows its evidence', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ArbolGenealogicoView(graph: _graph()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    expect(find.text('convergencia real'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/arbol_genealogico_view_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/graph/arbol_genealogico_view.dart
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../../models/creative_graph.dart';
import '../../models/node.dart' as model;
import 'node_detail_sheet.dart';
import 'turning_point_badge.dart';

const _rootId = 'root-tu';

class ArbolGenealogicoView extends StatefulWidget {
  const ArbolGenealogicoView({super.key, required this.graph});

  final CreativeGraph graph;

  @override
  State<ArbolGenealogicoView> createState() => _ArbolGenealogicoViewState();
}

class _ArbolGenealogicoViewState extends State<ArbolGenealogicoView> {
  final Set<String> _rejectedIds = {};

  void _showEvidence(String evidence) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Punto de inflexión'),
        content: Text(evidence),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final graph = widget.graph;
    final visibleNodes =
        graph.nodes.where((n) => !_rejectedIds.contains(n.id)).toList();
    final nodesById = {for (final node in visibleNodes) node.id: node};
    final turningPointIds = graph.turningPoints
        .where((tp) => tp.isVerified)
        .map((tp) => tp.nodeId)
        .toSet();
    final evidenceByNodeId = {
      for (final tp in graph.turningPoints.where((tp) => tp.isVerified))
        tp.nodeId: tp.evidence,
    };

    final graphViewGraph = Graph();
    graphViewGraph.addNode(Node.Id(_rootId));

    for (final node in visibleNodes.where((n) => n.level == 1)) {
      graphViewGraph.addEdge(Node.Id(_rootId), Node.Id(node.id));
    }
    for (final node in visibleNodes.where((n) => n.level == 2)) {
      final parentId = node.referenteOf;
      if (parentId != null && nodesById.containsKey(parentId)) {
        graphViewGraph.addEdge(Node.Id(parentId), Node.Id(node.id));
      }
    }
    for (final edge in graph.edges) {
      if (nodesById.containsKey(edge.source) && nodesById.containsKey(edge.target)) {
        graphViewGraph.addEdge(Node.Id(edge.source), Node.Id(edge.target));
      }
    }

    final configuration = SugiyamaConfiguration()
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
      ..nodeSeparation = 24
      ..levelSeparation = 48;

    return GraphView.builder(
      graph: graphViewGraph,
      algorithm: SugiyamaAlgorithm(configuration),
      builder: (node) {
        final id = node.key!.value as String;
        if (id == _rootId) {
          return const _TreeChip(label: 'TÚ', isRoot: true);
        }
        final modelNode = nodesById[id]!;
        return _TreeChip(
          label: modelNode.label,
          isSugerido: modelNode.origin == model.NodeOrigin.sugerido,
          hasTurningPoint: turningPointIds.contains(id),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => NodeDetailSheet(node: modelNode),
          ),
          onTurningPointTap: () => _showEvidence(evidenceByNodeId[id]!),
          onAccept: modelNode.origin == model.NodeOrigin.sugerido
              ? () {} // already visible; accepting just dismisses the prompt
              : null,
          onReject: modelNode.origin == model.NodeOrigin.sugerido
              ? () => setState(() => _rejectedIds.add(id))
              : null,
        );
      },
    );
  }
}

class _TreeChip extends StatelessWidget {
  const _TreeChip({
    required this.label,
    this.isRoot = false,
    this.isSugerido = false,
    this.hasTurningPoint = false,
    this.onTap,
    this.onTurningPointTap,
    this.onAccept,
    this.onReject,
  });

  final String label;
  final bool isRoot;
  final bool isSugerido;
  final bool hasTurningPoint;
  final VoidCallback? onTap;
  final VoidCallback? onTurningPointTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isRoot ? Colors.black87 : Colors.blueGrey.shade700,
          borderRadius: BorderRadius.circular(8),
          border: isSugerido
              ? Border.all(color: Colors.white70, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
            if (hasTurningPoint) ...[
              const SizedBox(width: 4),
              TurningPointBadge(onTap: onTurningPointTap ?? () {}),
            ],
            if (onAccept != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onAccept,
                child: const Icon(Icons.check, size: 14, color: Colors.greenAccent),
              ),
            ],
            if (onReject != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onReject,
                child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/arbol_genealogico_view_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/graph/arbol_genealogico_view.dart test/ui/arbol_genealogico_view_test.dart
git commit -m "feat: add Arbol Genealogico layered tree view"
```

---

## Task 24: Graph view screen (final wiring)

**Files:**
- Modify: `lib/ui/graph/graph_view_screen.dart` (replace the Task 20 placeholder)
- Test: `test/ui/graph_view_screen_test.dart`

**Interfaces:**
- Consumes: `GraphSession` (Task 7), `JardinDigitalView` (Task 22), `ArbolGenealogicoView` (Task 23).
- Produces: `class GraphViewScreen extends StatelessWidget { const GraphViewScreen({required GraphSession session}); }` with a two-tab `TabBar`/`TabBarView` and a follow-up-questions banner when `session.graph.followupQuestions` is non-empty.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/graph_view_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/models/creative_graph.dart';
import 'package:creative/models/node.dart';
import 'package:creative/models/session.dart';
import 'package:creative/ui/graph/graph_view_screen.dart';

GraphSession _sessionWithNode() => GraphSession(
      id: '1',
      rawInput: 'input',
      graph: const CreativeGraph(
        nodes: [
          Node(
            id: 'c1',
            type: NodeType.concepto,
            label: 'Cache manual',
            description: 'd',
            cluster: 'arquitectura-software',
            origin: NodeOrigin.usuario,
          ),
        ],
        edges: [],
        affinityEdges: [],
        turningPoints: [],
        followupQuestions: [],
      ),
      createdAt: DateTime.utc(2026, 9, 21),
    );

GraphSession _thinSession() => GraphSession(
      id: '2',
      rawInput: 'input corto',
      graph: const CreativeGraph(
        nodes: [],
        edges: [],
        affinityEdges: [],
        turningPoints: [],
        followupQuestions: ['¿Quién te enseñó esto?'],
      ),
      createdAt: DateTime.utc(2026, 9, 21),
    );

void main() {
  testWidgets('switches between Jardin Digital and Arbol Genealogico tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GraphViewScreen(session: _sessionWithNode())));
    await tester.pumpAndSettle();

    expect(find.text('Jardín Digital'), findsWidgets);
    expect(find.text('Árbol Genealógico'), findsWidgets);

    expect(find.text('Cache manual'), findsOneWidget);

    await tester.tap(find.text('Árbol Genealógico'));
    await tester.pumpAndSettle();

    expect(find.text('Cache manual'), findsOneWidget);
  });

  testWidgets('shows followup questions when the graph is thin', (tester) async {
    await tester.pumpWidget(MaterialApp(home: GraphViewScreen(session: _thinSession())));
    await tester.pumpAndSettle();

    expect(find.textContaining('¿Quién te enseñó esto?'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/graph_view_screen_test.dart`
Expected: FAIL — the placeholder screen from Task 20 has no tabs or followup-questions banner.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/graph/graph_view_screen.dart
import 'package:flutter/material.dart';

import '../../models/session.dart';
import 'arbol_genealogico_view.dart';
import 'jardin_digital_view.dart';

class GraphViewScreen extends StatelessWidget {
  const GraphViewScreen({super.key, required this.session});

  final GraphSession session;

  @override
  Widget build(BuildContext context) {
    final followupQuestions = session.graph.followupQuestions;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Genealogía Creativa'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Jardín Digital'),
            Tab(text: 'Árbol Genealógico'),
          ]),
        ),
        body: Column(
          children: [
            if (followupQuestions.isNotEmpty)
              MaterialBanner(
                content: Text(
                  'Para construir el árbol, respóndenos: ${followupQuestions.join(' ')}',
                ),
                actions: const [SizedBox.shrink()],
              ),
            Expanded(
              child: TabBarView(
                children: [
                  JardinDigitalView(graph: session.graph),
                  ArbolGenealogicoView(graph: session.graph),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/graph_view_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS — every test file from Tasks 1–24 green.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/graph/graph_view_screen.dart test/ui/graph_view_screen_test.dart
git commit -m "feat: wire Jardin Digital and Arbol Genealogico tabs into GraphViewScreen"
```

---

## Task 25: Manual end-to-end verification (not automated)

This task has no unit test — it exercises the real Anthropic API and the real `graphview` rendering, neither of which is meaningfully testable without a live key and a human looking at the layout.

- [ ] **Step 1: Run the app in the browser**

Use the built-in browser preview (`flutter run -d chrome` via the project's dev-server flow, or the Browser pane's `preview_start`).

- [ ] **Step 2: Enter a real Anthropic API key**

Tap the key icon on the session list screen, paste a real key, save.

- [ ] **Step 3: Generate a graph from a real devlog**

Paste a paragraph or two describing a real creative/engineering process (mixing at least two unrelated domains, e.g. a bug fix and something read outside of work) into the input screen and tap "Generar".

- [ ] **Step 4: Verify both views**

Confirm: the Jardín Digital shows every node (including any loose fragments) grouped visually by cluster color; the Árbol Genealógico shows TÚ at the root, any referentes below it, and the concept lineage hanging off the Fuentes that fed it; any turning-point badge's evidence text matches something the input actually said; no node appears twice; rejecting a sugerido node removes it.

- [ ] **Step 5: Note any real-world mismatches**

If the model's output doesn't match the system prompt's rules in practice (e.g. a Fuente→Fuente edge the parser had to reject, or `max_tokens` truncating a large graph), record it — that's tuning for the system prompt / `max_tokens` constant, not a code defect in this plan.

---

## Self-Review Notes

- **Spec coverage:** node/edge model (Tasks 2–6), referente pedigree via `level`/`referenteOf` attributes not lineage edges (Task 2, 23), turning-point convergence/direction-change verification (Task 11), acyclicity enforcement (Task 11), tool-forced Anthropic call (Tasks 8, 9, 12), retry-once-then-fail parsing (Task 14), local session persistence (Task 15), Jardín Digital force-directed + loose fragments (Task 22), Árbol Genealógico layered tree + TÚ root + accept/reject + turning-point badges (Task 23), followup_questions surfaced for thin input (Task 24), API key entry (Task 18).
- **Type consistency:** `GraphGenerationClient.requestToolCall` (Task 12) is consumed with identical signature in `GenerationEngine` (Task 14); `ApiKeyStore`/`SessionStore`/`GraphGenerator` interfaces (Tasks 13, 15, 14) match their fakes in `test/helpers/fakes.dart` and their real usages in Tasks 16–20; `TurningPoint.copyWith` (Task 5) is used as-is by `graph_verifier.dart` (Task 11).
- **Placeholder scan:** the only literal "TODO" in the plan is the Task 20 placeholder body of `GraphViewScreen`, which Task 24 explicitly replaces in full — not a deferred requirement.

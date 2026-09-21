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

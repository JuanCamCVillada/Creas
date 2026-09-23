import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creative/engine/icon_catalog.dart';
import 'package:creative/models/node.dart';
import 'package:creative/ui/graph/node_icons.dart';

Node _node({String? icon, NodeType type = NodeType.concepto}) => Node(
      id: 'n1',
      type: type,
      label: 'l',
      description: 'd',
      cluster: 'c',
      origin: NodeOrigin.usuario,
      icon: icon,
    );

void main() {
  group('allowedNodeIconNames / nodeIconByName parity', () {
    test('every allowed icon name has a mapped IconData, and vice versa', () {
      expect(allowedNodeIconNames, isNotEmpty);
      expect(nodeIconByName.keys.toSet(), allowedNodeIconNames.toSet());
    });
  });

  group('iconForNode', () {
    test('returns the mapped icon when the node has a valid, allowed icon name', () {
      final node = _node(icon: 'bug_report');
      expect(iconForNode(node), Icons.bug_report);
    });

    test('falls back to a default when icon is null', () {
      final node = _node();
      expect(iconForNode(node), isNotNull);
    });

    test('falls back to a default when icon is not in the allowed list', () {
      final node = _node(icon: 'not_a_real_icon_name');
      expect(iconForNode(node), isNot(throwsA(anything)));
      expect(iconForNode(node), isNotNull);
    });

    test('defaults differ between fuente and concepto when icon is absent', () {
      final fuente = _node(type: NodeType.fuente);
      final concepto = _node(type: NodeType.concepto);
      expect(iconForNode(fuente), isNot(iconForNode(concepto)));
    });
  });
}

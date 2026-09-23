import 'package:flutter/material.dart';

import '../../engine/icon_catalog.dart';
import '../../models/node.dart';

/// Maps each allowed icon name (see [allowedNodeIconNames]) to its Flutter
/// IconData. The key set here must stay identical to [allowedNodeIconNames].
const Map<String, IconData> nodeIconByName = {
  'code': Icons.code,
  'bug_report': Icons.bug_report,
  'music_note': Icons.music_note,
  'menu_book': Icons.menu_book,
  'forum': Icons.forum,
  'lightbulb': Icons.lightbulb,
  'school': Icons.school,
  'eco': Icons.eco,
  'storage': Icons.storage,
  'cloud': Icons.cloud,
  'memory': Icons.memory,
  'palette': Icons.palette,
  'videocam': Icons.videocam,
  'camera_alt': Icons.camera_alt,
  'person': Icons.person,
  'groups': Icons.groups,
  'event': Icons.event,
  'star': Icons.star,
  'science': Icons.science,
  'build': Icons.build,
  'timeline': Icons.timeline,
  'insights': Icons.insights,
  'psychology': Icons.psychology,
  'rocket_launch': Icons.rocket_launch,
  'warning': Icons.warning,
  'map': Icons.map,
};

const _defaultFuenteIcon = Icons.input;
const _defaultConceptoIcon = Icons.emoji_objects;

/// Resolves the icon to render for [node]: the model-chosen icon when it's
/// a valid, allowed name, otherwise a neutral default that still
/// distinguishes a Fuente from a Concepto.
IconData iconForNode(Node node) {
  final chosen = node.icon;
  if (chosen != null && nodeIconByName.containsKey(chosen)) {
    return nodeIconByName[chosen]!;
  }
  return node.type == NodeType.fuente
      ? _defaultFuenteIcon
      : _defaultConceptoIcon;
}

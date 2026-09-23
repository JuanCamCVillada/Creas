/// The exact set of Material Symbols icon names Gemini may choose from for a
/// node's `icon` field. Kept deliberately small so the icon stays a subtle
/// visual hint, not a decoration attempt for every possible concept — see
/// system_prompt.dart, where the model is told to omit `icon` rather than
/// force a poor match. The tool schema's enum and the UI's icon lookup both
/// derive from this single list so they can never drift apart.
const List<String> allowedNodeIconNames = [
  'code',
  'bug_report',
  'music_note',
  'menu_book',
  'forum',
  'lightbulb',
  'school',
  'eco',
  'storage',
  'cloud',
  'memory',
  'palette',
  'videocam',
  'camera_alt',
  'person',
  'groups',
  'event',
  'star',
  'science',
  'build',
  'timeline',
  'insights',
  'psychology',
  'rocket_launch',
  'warning',
  'map',
];

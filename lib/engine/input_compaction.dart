/// The user's text with the whitespace that carries no meaning removed, so it
/// isn't paid for as input tokens: trailing spaces on each line, and runs of
/// blank lines collapsed to one (a pasted devlog is often full of both).
///
/// Deliberately leaves everything else alone — in particular the spaces
/// inside a line, so pasted code keeps its indentation and the model sees
/// exactly what the user wrote.
String compactInput(String input) {
  final lines = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final kept = <String>[];
  var blankRun = 0;
  for (final line in lines) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) {
      blankRun++;
      if (blankRun > 1) continue;
    } else {
      blankRun = 0;
    }
    kept.add(trimmed);
  }
  // Drop blank lines at the ends, but not spaces at the start of the first
  // real line — a plain trim() would strip a leading indent.
  while (kept.isNotEmpty && kept.first.isEmpty) {
    kept.removeAt(0);
  }
  while (kept.isNotEmpty && kept.last.isEmpty) {
    kept.removeLast();
  }
  return kept.join('\n');
}

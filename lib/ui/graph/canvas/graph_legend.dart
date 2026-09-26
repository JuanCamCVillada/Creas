import 'package:flutter/material.dart';

import '../../theme/hud_tokens.dart';
import '../../theme/hud_text.dart';
import '../../theme/hud_widgets.dart';
import 'node_shapes.dart';

/// One shape-to-meaning mapping shown in a [GraphLegend], e.g. hexagon =
/// Fuente. Kept separate from the node cells themselves so the legend can
/// be positioned outside the pannable canvas and never scroll out of view.
class GraphLegendShape {
  const GraphLegendShape({required this.kind, required this.label, required this.color});
  final NodeShapeKind kind;
  final String label;
  final Color color;
}

/// One edge-style-to-meaning mapping, e.g. solid = linaje verificado.
class GraphLegendLine {
  const GraphLegendLine({required this.label, required this.dashed, this.color});
  final String label;
  final bool dashed;
  final Color? color;
}

/// A fixed key explaining a graph's shapes and line styles — the "leyenda"
/// the reference HUD screens always keep visible at the bottom of the
/// canvas, so a first-time reader isn't left guessing what a hexagon or a
/// dashed edge means.
class GraphLegend extends StatelessWidget {
  const GraphLegend({super.key, required this.shapes, required this.lines, this.fullWidth = false});

  final List<GraphLegendShape> shapes;
  final List<GraphLegendLine> lines;

  /// true on the wide dashboard layout, where the legend is a flat bar
  /// spanning the whole center column (matching the reference screens'
  /// bottom key) instead of a floating box in a corner of the canvas.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final entries = Wrap(
      spacing: 16,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final shape in shapes) _shapeEntry(c, shape),
        for (final line in lines) _lineEntry(c, line),
      ],
    );

    if (fullWidth) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: c.panel,
          border: Border(top: BorderSide(color: c.grid)),
        ),
        child: entries,
      );
    }

    return HudChamferedBox(
      fill: c.panel.withValues(alpha: 0.92),
      borderColor: c.grid,
      borderWidth: 1,
      chamfer: 6,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: entries,
    );
  }

  Widget _shapeEntry(HudColors c, GraphLegendShape shape) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeShape(
          kind: shape.kind,
          size: 16,
          fill: shape.color.withValues(alpha: 0.35),
          border: shape.color,
          borderWidth: 1.5,
          child: const SizedBox.shrink(),
        ),
        const SizedBox(width: 6),
        Text(shape.label, style: HudText.operativa(c.text2, size: 11)),
      ],
    );
  }

  Widget _lineEntry(HudColors c, GraphLegendLine line) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 10,
          child: CustomPaint(painter: _LineSwatchPainter(line.color ?? c.data, line.dashed)),
        ),
        const SizedBox(width: 6),
        Text(line.label, style: HudText.operativa(c.text2, size: 11)),
      ],
    );
  }
}

class _LineSwatchPainter extends CustomPainter {
  _LineSwatchPainter(this.color, this.dashed);
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(0, size.width), y), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _LineSwatchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

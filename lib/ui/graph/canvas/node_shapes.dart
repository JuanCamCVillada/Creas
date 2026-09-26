import 'dart:math' as math;

import 'package:flutter/material.dart';

enum NodeShapeKind { hexagon, circle, diamond, doubleRing }

/// A single node's frame: hexagon (Fuente), circle (Concepto), diamond
/// (verified turning point), or a double-ringed circle (a lineage sink —
/// the current end state of a chain). [dashedBorder] marks a sugerido node.
class NodeShape extends StatelessWidget {
  const NodeShape({
    super.key,
    required this.kind,
    required this.size,
    required this.fill,
    required this.border,
    this.dashedBorder = false,
    this.borderWidth = 2,
    required this.child,
  });

  final NodeShapeKind kind;
  final double size;
  final Color fill;
  final Color border;
  final bool dashedBorder;
  final double borderWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShapePainter(
          kind: kind,
          fill: fill,
          border: border,
          dashedBorder: dashedBorder,
          borderWidth: borderWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({
    required this.kind,
    required this.fill,
    required this.border,
    required this.dashedBorder,
    required this.borderWidth,
  });

  final NodeShapeKind kind;
  final Color fill;
  final Color border;
  final bool dashedBorder;
  final double borderWidth;

  Path _hexagon(Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 90);
      final point = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path _diamond(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
  }

  void _strokePath(Canvas canvas, Path path, Paint paint) {
    if (!dashedBorder) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final next = distance + (draw ? 4.0 : 3.0);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = fill..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    switch (kind) {
      case NodeShapeKind.hexagon:
        final path = _hexagon(size);
        canvas.drawPath(path, fillPaint);
        _strokePath(canvas, path, borderPaint);
      case NodeShapeKind.diamond:
        final path = _diamond(size);
        canvas.drawPath(path, fillPaint);
        _strokePath(canvas, path, borderPaint);
      case NodeShapeKind.circle:
        final center = Offset(size.width / 2, size.height / 2);
        final radius = size.width / 2 - borderWidth;
        canvas.drawCircle(center, radius, fillPaint);
        final circlePath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
        _strokePath(canvas, circlePath, borderPaint);
      case NodeShapeKind.doubleRing:
        final center = Offset(size.width / 2, size.height / 2);
        final outer = size.width / 2 - borderWidth;
        canvas.drawCircle(center, outer, fillPaint);
        final outerPath = Path()..addOval(Rect.fromCircle(center: center, radius: outer));
        _strokePath(canvas, outerPath, borderPaint);
        final innerPath = Path()..addOval(Rect.fromCircle(center: center, radius: outer - 5));
        _strokePath(canvas, innerPath, borderPaint..strokeWidth = borderWidth * 0.7);
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.fill != fill ||
      oldDelegate.border != border ||
      oldDelegate.dashedBorder != dashedBorder;
}

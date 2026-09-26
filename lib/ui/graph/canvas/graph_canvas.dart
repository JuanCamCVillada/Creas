import 'package:flutter/material.dart';

/// A directed connector between two node ids drawn by [GraphCanvas].
class GraphCanvasEdge {
  const GraphCanvasEdge({
    required this.fromId,
    required this.toId,
    this.dashed = false,
    this.color,
  });

  final String fromId;
  final String toId;

  /// hud-tactico maps "inspira" (a looser influence) to a dashed connector,
  /// keeping solid lines for the firmer relations (desencadena, deriva_de,
  /// transforma_en) — see `arbol_genealogico_view.dart`.
  final bool dashed;
  final Color? color;
}

typedef GraphCanvasNodeBuilder = Widget Function(BuildContext context, String id);

/// A pannable, zoomable canvas of freely-draggable nodes connected by curved
/// bezier edges. Positions start at [initialPositions] and are then owned by
/// the user's drags for the life of this widget — dragging a node only
/// updates its own position, nothing re-flows.
class GraphCanvas extends StatefulWidget {
  const GraphCanvas({
    super.key,
    required this.nodeIds,
    required this.initialPositions,
    required this.edges,
    required this.nodeBuilder,
    required this.nodeSize,
    this.canvasSize = const Size(2600, 1400),
    this.edgeColor = const Color(0xFF47C5FB),
  });

  final List<String> nodeIds;
  final Map<String, Offset> initialPositions;
  final List<GraphCanvasEdge> edges;
  final GraphCanvasNodeBuilder nodeBuilder;
  final Size nodeSize;
  final Size canvasSize;
  final Color edgeColor;

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas> {
  late Map<String, Offset> _positions;
  final _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _positions = Map.of(widget.initialPositions);
  }

  @override
  void didUpdateWidget(covariant GraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep drags for nodes that are still present; adopt fresh positions
    // for any node id that just appeared (e.g. after a rejection changed
    // the visible set); drop ids that disappeared.
    for (final id in widget.nodeIds) {
      _positions.putIfAbsent(id, () => widget.initialPositions[id] ?? Offset.zero);
    }
    _positions.removeWhere((id, _) => !widget.nodeIds.contains(id));
  }

  double get _scale => _transformController.value.getMaxScaleOnAxis();

  void _dragNode(String id, Offset delta) {
    setState(() {
      _positions = Map.of(_positions)
        ..[id] = (_positions[id] ?? Offset.zero) + delta / _scale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformController,
      constrained: false,
      minScale: 0.4,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(400),
      child: SizedBox(
        width: widget.canvasSize.width,
        height: widget.canvasSize.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EdgePainter(
                  positions: _positions,
                  edges: widget.edges,
                  color: widget.edgeColor,
                ),
              ),
            ),
            for (final id in widget.nodeIds)
              Positioned(
                left: (_positions[id]?.dx ?? 0) - widget.nodeSize.width / 2,
                top: (_positions[id]?.dy ?? 0) - widget.nodeSize.height / 2,
                width: widget.nodeSize.width,
                height: widget.nodeSize.height,
                child: GestureDetector(
                  onPanUpdate: (details) => _dragNode(id, details.delta),
                  child: widget.nodeBuilder(context, id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.positions, required this.edges, required this.color});

  final Map<String, Offset> positions;
  final List<GraphCanvasEdge> edges;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      if (from == null || to == null) continue;

      final pull = (to.dx - from.dx).abs().clamp(40.0, 220.0);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx + pull, from.dy, to.dx - pull, to.dy, to.dx, to.dy);

      final paint = Paint()
        ..color = (edge.color ?? color).withValues(alpha: edge.dashed ? 0.5 : 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = edge.dashed ? 1.4 : 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(edge.dashed ? _dashed(path) : path, paint);
    }
  }

  Path _dashed(Path source, {double dashLength = 6, double gapLength = 5}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final next = distance + (draw ? dashLength : gapLength);
        if (draw) {
          result.addPath(metric.extractPath(distance, next.clamp(0, metric.length)), Offset.zero);
        }
        distance = next;
        draw = !draw;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) => true;
}

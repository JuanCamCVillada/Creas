import 'package:flutter/material.dart';

/// A directed connector between two node ids drawn by [GraphCanvas].
class GraphCanvasEdge {
  const GraphCanvasEdge({
    required this.fromId,
    required this.toId,
    this.dashed = false,
    this.color,
    this.width,
  });

  final String fromId;
  final String toId;

  /// hud-tactico maps "inspira" (a looser influence) to a dashed connector,
  /// keeping solid lines for the firmer relations (desencadena, deriva_de,
  /// transforma_en) — see `arbol_genealogico_view.dart`.
  final bool dashed;
  final Color? color;

  /// Overrides the default stroke width (1.4 dashed / 2.2 solid) — lets a
  /// caller encode a continuous value (e.g. affinity weight) as line
  /// thickness instead of alpha alone, since color/opacity by itself is a
  /// weak, easy-to-miss signal for "strong vs weak" at a glance.
  final double? width;
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
    this.backgroundBuilder,
  });

  final List<String> nodeIds;
  final Map<String, Offset> initialPositions;
  final List<GraphCanvasEdge> edges;
  final GraphCanvasNodeBuilder nodeBuilder;
  final Size nodeSize;
  final Size canvasSize;
  final Color edgeColor;

  /// Painted behind the edges and nodes, in the same (already origin-
  /// shifted) coordinate space as the positions [nodeBuilder] receives —
  /// e.g. Jardín Digital uses this to paint the orbit rings its own
  /// layout algorithm computes, so a "loose" node's ring is an actual
  /// visible boundary instead of just a text label.
  final Widget Function(Map<String, Offset> positions)? backgroundBuilder;

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

const _contentPadding = 100.0;

class _GraphCanvasState extends State<GraphCanvas> {
  late Map<String, Offset> _positions;
  late Offset _originOffset;
  late Size _contentSize;
  final _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _computeOrigin();
    _positions = {
      for (final entry in widget.initialPositions.entries)
        entry.key: entry.value + _originOffset,
    };
  }

  /// Positions coming from callers (a cluster hash-grid, a generation
  /// column layout, …) can land anywhere, including far from the origin
  /// or with a negative min. Shift everything so the content's bounding
  /// box always starts near (0,0) — otherwise a graph can render entirely
  /// outside the viewport's initial pan/zoom with no visible nodes at all.
  void _computeOrigin() {
    final raw = widget.initialPositions;
    if (raw.isEmpty) {
      _originOffset = const Offset(_contentPadding, _contentPadding);
      _contentSize = widget.canvasSize;
      return;
    }
    final xs = raw.values.map((o) => o.dx);
    final ys = raw.values.map((o) => o.dy);
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    _originOffset = Offset(_contentPadding - minX, _contentPadding - minY);
    final contentWidth = (maxX - minX) + _contentPadding * 2 + widget.nodeSize.width;
    final contentHeight = (maxY - minY) + _contentPadding * 2 + widget.nodeSize.height;
    _contentSize = Size(
      contentWidth > widget.canvasSize.width ? contentWidth : widget.canvasSize.width,
      contentHeight > widget.canvasSize.height ? contentHeight : widget.canvasSize.height,
    );
  }

  @override
  void didUpdateWidget(covariant GraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep drags for nodes that are still present; adopt fresh (normalized)
    // positions for any node id that just appeared (e.g. after a rejection
    // changed the visible set); drop ids that disappeared.
    for (final id in widget.nodeIds) {
      _positions.putIfAbsent(
        id,
        () => (widget.initialPositions[id] ?? Offset.zero) + _originOffset,
      );
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
        width: _contentSize.width,
        height: _contentSize.height,
        child: Stack(
          children: [
            if (widget.backgroundBuilder != null)
              Positioned.fill(child: widget.backgroundBuilder!(_positions)),
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
      final drawnPath = edge.dashed ? _dashed(path) : path;
      final edgeColor = edge.color ?? color;

      // A wider, blurred stroke under the crisp one gives the connector a
      // neon glow instead of a flat line — cheap to draw (one extra
      // drawPath) and reads as "alive" the way the reference HUD screens
      // do, rather than looking like a plain vector diagram.
      final glowPaint = Paint()
        ..color = edgeColor.withValues(alpha: edge.dashed ? 0.18 : 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = edge.dashed ? 5 : 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(drawnPath, glowPaint);

      final paint = Paint()
        ..color = edgeColor.withValues(alpha: edge.dashed ? 0.5 : 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = edge.width ?? (edge.dashed ? 1.4 : 2.2)
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(drawnPath, paint);

      // A small "+" at the path's midpoint, echoing the reference screens'
      // junction ticks along each connector — purely typographic flavor,
      // dim enough to never compete with the line or the nodes it joins.
      _drawPlusMark(canvas, path, edgeColor);
    }
  }

  void _drawPlusMark(Canvas canvas, Path path, Color edgeColor) {
    for (final metric in path.computeMetrics()) {
      final tangent = metric.getTangentForOffset(metric.length / 2);
      if (tangent == null) continue;
      final p = tangent.position;
      final markPaint = Paint()
        ..color = edgeColor.withValues(alpha: 0.55)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p + const Offset(-4, 0), p + const Offset(4, 0), markPaint);
      canvas.drawLine(p + const Offset(0, -4), p + const Offset(0, 4), markPaint);
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

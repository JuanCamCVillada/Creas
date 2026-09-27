import 'package:flutter/material.dart';

import '../../theme/hud_tokens.dart';
import '../../theme/hud_text.dart';
import '../turning_point_badge.dart';
import 'node_shapes.dart';

/// The fixed size [GraphCanvas] reserves for every [GraphNodeCell] — tall
/// enough for a header label (generation/cluster caption) and a badge row
/// (accept/reject, turning-point) to both be present at once. Both graph
/// views share this constant instead of guessing at it independently, so
/// they can't silently drift apart.
const kGraphNodeCellSize = Size(150, 162);

/// The single node-cell widget both graph views render inside [GraphCanvas]:
/// a shape (meaning decided by the caller — hexagon/circle/diamond/double
/// ring), an id code, the node's own label and cluster, and an optional row
/// of interactive badges (turning-point evidence, accept/reject). Having one
/// shared cell means both views always look and behave consistently — a
/// change here reaches Jardín Digital and Árbol Genealógico alike.
class GraphNodeCell extends StatelessWidget {
  const GraphNodeCell({
    super.key,
    required this.label,
    required this.cluster,
    required this.code,
    required this.shapeKind,
    required this.fill,
    required this.icon,
    required this.onTap,
    this.isSugerido = false,
    this.generationLabel,
    this.glow = false,
    this.hasTurningPoint = false,
    this.onTurningPointTap,
    this.onAccept,
    this.onReject,
  });

  final String label;
  final String cluster;
  final String code;
  final NodeShapeKind shapeKind;
  final Color fill;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSugerido;

  /// e.g. "G-2" — shown above the shape. Only meaningful for a directed,
  /// generational layout (Árbol); omitted (null) in Jardín Digital.
  final String? generationLabel;

  /// A soft halo behind the shape — reserved for the nodes a screen wants
  /// to draw the eye to (a turning point, a synthesis sink), not applied
  /// to every cell.
  final bool glow;

  final bool hasTurningPoint;
  final VoidCallback? onTurningPointTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    // Positioned to a fixed pixel box by GraphCanvas — this is canvas
    // content, not scrolling document text, so it deliberately opts out of
    // the system text-scale setting. Without this, a viewer with a larger
    // accessibility text size overflows the fixed-height cell on every
    // node; the cell's own information (code, label, cluster) stays fully
    // readable via zooming the canvas itself instead.
    return MediaQuery.withNoTextScaling(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (generationLabel != null)
            Text(
              generationLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HudText.terminal(c.textDim, size: 9),
            ),
          // Only the shape + its labels open the detail sheet — the badge
          // row below is a sibling, not a descendant, of this tap target.
          // Nesting a GestureDetector inside another (the previous
          // structure) let a tap on accept/reject also fire the outer
          // onTap, since both are on the same pointer-down hit-test path.
          GestureDetector(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NodeShape(
                  kind: shapeKind,
                  size: 52,
                  fill: fill,
                  border: isSugerido ? c.text2 : fill,
                  dashedBorder: isSugerido,
                  glow: glow,
                  child: Icon(icon, size: 16, color: c.text),
                ),
                const SizedBox(height: 4),
                Text(code, style: HudText.terminal(c.id, size: 10)),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  cluster,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HudText.terminal(c.textDim, size: 9),
                ),
              ],
            ),
          ),
          if (hasTurningPoint || onAccept != null || onReject != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasTurningPoint)
                  TurningPointBadge(onTap: onTurningPointTap ?? () {}),
                if (onAccept != null)
                  _HitTarget(
                    onTap: onAccept!,
                    child: Icon(Icons.check, size: 14, color: c.signal),
                  ),
                if (onReject != null)
                  _HitTarget(
                    onTap: onReject!,
                    child: Icon(Icons.close, size: 14, color: c.deny),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Wraps a small icon control with the 28x28pt minimum tap target
/// (accessibility.md § Mobility) without inflating its visible size.
class _HitTarget extends StatelessWidget {
  const _HitTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 28, height: 28, child: Center(child: child)),
    );
  }
}

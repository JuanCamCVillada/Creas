import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hud_tokens.dart';
import 'hud_text.dart';

/// A panel or chip with two chamfered (45°-cut) corners instead of rounded
/// ones, per hud-tactico §4 ("Nada de border-radius, salvo las pastillas").
/// Paints fill and stroke from the same path so the border follows the cut
/// corners correctly.
class HudChamferedBox extends StatelessWidget {
  const HudChamferedBox({
    super.key,
    required this.child,
    this.fill,
    this.borderColor,
    this.borderWidth = 2,
    this.chamfer = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final Color? fill;
  final Color? borderColor;
  final double borderWidth;
  final double chamfer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChamferPainter(
        chamfer: chamfer,
        fill: fill,
        borderColor: borderColor,
        borderWidth: borderWidth,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _ChamferPainter extends CustomPainter {
  _ChamferPainter({
    required this.chamfer,
    this.fill,
    this.borderColor,
    required this.borderWidth,
  });

  final double chamfer;
  final Color? fill;
  final Color? borderColor;
  final double borderWidth;

  Path _path(Size size) {
    final c = chamfer.clamp(0.0, size.shortestSide / 2);
    return Path()
      ..moveTo(c, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, c)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill!..style = PaintingStyle.fill);
    }
    if (borderColor != null && borderWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChamferPainter oldDelegate) =>
      oldDelegate.chamfer != chamfer ||
      oldDelegate.fill != fill ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}

/// Primary action button: achaflanado, borde --sys, "▶" leading glyph —
/// hud-tactico §5 "Botón". Pass [label] already in the app's uppercase
/// convention (e.g. "GENERAR") — this widget doesn't transform it, so
/// widget tests can find it by its exact, literal text.
class HudButton extends StatelessWidget {
  const HudButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final enabled = onPressed != null && !loading;
    return InkWell(
      onTap: enabled ? onPressed : null,
      child: HudChamferedBox(
        fill: enabled ? c.bg : c.grid,
        borderColor: c.sys,
        borderWidth: 2,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const HudBlockProgress(width: 28, height: 10, blockCount: 6)
            else
              Text('▶', style: TextStyle(color: c.sys, fontSize: 14)),
            const SizedBox(width: 8),
            Text(label, style: HudText.operativa(c.sys, size: 15)),
          ],
        ),
      ),
    );
  }
}

/// Rótulo de identificación: doble borde --id, mayúsculas condensadas.
/// hud-tactico §5 "Rótulo de identificación" — one per screen.
class HudIdBadge extends StatelessWidget {
  const HudIdBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return HudChamferedBox(
      fill: Colors.transparent,
      borderColor: c.id,
      borderWidth: 1.5,
      chamfer: 6,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(label.toUpperCase(), style: HudText.operativa(c.id, size: 12)),
    );
  }
}

/// Etiqueta pequeña + valor grande en mono — hud-tactico §5 "Readout".
class HudReadout extends StatelessWidget {
  const HudReadout({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: HudText.operativa(c.text2, size: 11)),
        const SizedBox(height: 2),
        Text(value, style: HudText.terminal(valueColor ?? c.ok, size: 18)),
      ],
    );
  }
}

/// Segmented tab control — a filled rectangle for the active tab, a plain
/// label for the rest, matching the reference HUD screens' "01 GRAFO / 02
/// FUENTES" tab strip instead of Material's underline indicator. Purely a
/// selector: it holds no state of its own, so it drives whatever the
/// caller uses for the actual page switch (a TabController, a index in
/// State, …).
class HudSegmentedTabs extends StatelessWidget {
  const HudSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          InkWell(
            onTap: () => onSelected(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: i == selectedIndex ? c.sys : Colors.transparent,
                border: Border.all(color: i == selectedIndex ? c.sys : c.grid),
              ),
              child: Text(
                labels[i],
                style: HudText.operativa(i == selectedIndex ? c.bg : c.textDim, size: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Barra de sincronización: reemplaza los spinners genéricos — hud-tactico
/// §5 "Barra de sincronización: … bloques `--sys` sobre `--grid`". No shows
/// a percentage: the app has no real progress signal to report, and
/// fabricating one would be dishonest (loading.md: determinate only when
/// you actually know how long it'll take). Indeterminate progress reads
/// instead as a scanning highlight sweeping the blocks — hud-tactico §6
/// "Barrido: línea de escaneo lineal" is exactly this case.
class HudSyncIndicator extends StatelessWidget {
  const HudSyncIndicator({super.key, this.label = 'SINCRONIZANDO'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HudBlockProgress(width: 120, height: 12, blockCount: 18),
        const SizedBox(width: 10),
        Text('$label…', style: HudText.terminal(c.text2, size: 13)),
      ],
    );
  }
}

/// The block-style progress bar itself, reused by [HudButton]'s loading
/// state and [HudSyncIndicator]: a row of ticks in `--grid`, with a short
/// run of `--sys` ticks sweeping left to right on a loop. Respects
/// reduced-motion (hud-tactico §8 / WCAG 2.3.1): the sweep freezes at a
/// single static position instead of animating.
class HudBlockProgress extends StatefulWidget {
  const HudBlockProgress({
    super.key,
    this.width = 120,
    this.height = 12,
    this.blockCount = 18,
    this.progress,
  });

  final double width;
  final double height;
  final int blockCount;

  /// null (the default): indeterminate — a sweep, no fabricated number.
  /// 0.0–1.0: determinate — fills that fraction of the blocks solid, no
  /// animation. Only pass this when the caller genuinely knows how far
  /// along it is (e.g. "step 2 of 5"), never to fake a percentage for a
  /// process with no real progress signal (loading.md).
  final double? progress;

  @override
  State<HudBlockProgress> createState() => _HudBlockProgressState();
}

class _HudBlockProgressState extends State<HudBlockProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;

    if (widget.progress != null) {
      final filled = (widget.blockCount * widget.progress!.clamp(0.0, 1.0)).round();
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _BlockProgressPainter.fill(
            blockCount: widget.blockCount,
            filledCount: filled,
            active: c.sys,
            inactive: c.grid,
          ),
        ),
      );
    }

    final highlightSpan = math.max(2, (widget.blockCount * 0.28).round()).toDouble();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _BlockProgressPainter.sweep(
            blockCount: widget.blockCount,
            highlightStart: (widget.blockCount - highlightSpan) / 2,
            highlightSpan: highlightSpan,
            active: c.sys,
            inactive: c.grid,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final travel = widget.blockCount + highlightSpan;
          final highlightStart = _controller.value * travel - highlightSpan;
          return CustomPaint(
            painter: _BlockProgressPainter.sweep(
              blockCount: widget.blockCount,
              highlightStart: highlightStart,
              highlightSpan: highlightSpan,
              active: c.sys,
              inactive: c.grid,
            ),
          );
        },
      ),
    );
  }
}

class _BlockProgressPainter extends CustomPainter {
  _BlockProgressPainter.sweep({
    required this.blockCount,
    required double highlightStart,
    required double highlightSpan,
    required this.active,
    required this.inactive,
  })  : _highlightStart = highlightStart,
        _highlightSpan = highlightSpan,
        _filledCount = null;

  _BlockProgressPainter.fill({
    required this.blockCount,
    required int filledCount,
    required this.active,
    required this.inactive,
  })  : _filledCount = filledCount,
        _highlightStart = 0,
        _highlightSpan = 0;

  final int blockCount;
  final double _highlightStart;
  final double _highlightSpan;
  final int? _filledCount;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    const gapFraction = 0.28;
    final blockWidth = size.width / (blockCount + (blockCount - 1) * gapFraction);
    final gap = blockWidth * gapFraction;
    final filledCount = _filledCount;

    for (var i = 0; i < blockCount; i++) {
      final rect = Rect.fromLTWH(i * (blockWidth + gap), 0, blockWidth, size.height);

      if (filledCount != null) {
        // Determinate: a hard fill boundary with a glow right on the
        // leading edge, like a bar filling up rather than a scan.
        final isFilled = i < filledCount;
        final isLeadingEdge = i == filledCount - 1;
        if (isLeadingEdge) {
          canvas.drawRect(
            rect.inflate(1.5),
            Paint()
              ..color = active.withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        canvas.drawRect(rect, Paint()..color = isFilled ? active : inactive);
        continue;
      }

      final distanceFromHighlight = (i + 0.5) - (_highlightStart + _highlightSpan / 2);
      // Blocks nearer the highlight's center glow brighter, fading out
      // toward its edges — a soft scan rather than a hard on/off tick.
      final proximity = (1 - (distanceFromHighlight.abs() / (_highlightSpan / 2 + 0.5)))
          .clamp(0.0, 1.0);
      final color = Color.lerp(inactive, active, proximity)!;

      if (proximity > 0.5) {
        canvas.drawRect(
          rect.inflate(1.5),
          Paint()
            ..color = active.withValues(alpha: 0.35 * proximity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _BlockProgressPainter oldDelegate) =>
      oldDelegate._highlightStart != _highlightStart ||
      oldDelegate._filledCount != _filledCount ||
      oldDelegate.blockCount != blockCount ||
      oldDelegate.active != active ||
      oldDelegate.inactive != inactive;
}

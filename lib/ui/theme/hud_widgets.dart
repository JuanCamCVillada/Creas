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
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.sys),
              )
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

/// Barra de sincronización: reemplaza los spinners genéricos.
/// Indeterminate here since the app has no real progress signal to report —
/// showing a fake percentage would be dishonest (loading.md: determinate
/// only when you actually know how long it'll take).
class HudSyncIndicator extends StatelessWidget {
  const HudSyncIndicator({super.key, this.label = 'SINCRONIZANDO'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.sys),
        ),
        const SizedBox(width: 10),
        Text('$label…', style: HudText.terminal(c.text2, size: 13)),
      ],
    );
  }
}

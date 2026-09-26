import 'package:flutter/material.dart';

import 'hud_tokens.dart';
import 'hud_text.dart';

extension on HudStatus {
  String get _glyph => switch (this) {
        HudStatus.nominal => '正常',
        HudStatus.precaucion => '注意',
        HudStatus.emergencia => '緊急',
      };

  String get _label => switch (this) {
        HudStatus.nominal => 'NOMINAL',
        HudStatus.precaucion => 'PRECAUCIÓN',
        HudStatus.emergencia => 'EMERGENCIA',
      };
}

/// Small status pill — CJK glyph + Spanish label, bordered in the status's
/// accent color. Mirrors the app's own three-state model (hud-tactico §7)
/// instead of inventing new ones; used wherever a screen or graph has a
/// real signal to report (never shown just for decoration).
class HudStatusBadge extends StatelessWidget {
  const HudStatusBadge({super.key, required this.status});

  final HudStatus status;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final accent = status.accent(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: accent, width: 1.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status._glyph, style: HudText.operativa(accent, size: 13)),
          const SizedBox(width: 6),
          Text(status._label, style: HudText.operativa(accent, size: 12)),
        ],
      ),
    );
  }
}

/// Hazard banner: a diagonal-striped warning tape (top and bottom) framing
/// a CJK glyph and a message — for real precaución/emergencia conditions
/// only (a low-confidence fuente, a hard generation failure), never for
/// decoration. Matches the user's own hud-tactico reference screens.
class HudHazardBanner extends StatelessWidget {
  const HudHazardBanner({
    super.key,
    required this.status,
    required this.title,
    this.subtitle,
    this.glyph = '警報',
    this.actions = const [],
  });

  final HudStatus status;
  final String title;
  final String? subtitle;
  final String glyph;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = HudColors.consola;
    final accent = status.accent(c);
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(painter: _HazardStripePainter(accent), size: const Size(double.infinity, 8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(border: Border.all(color: accent)),
                  child: Text(
                    glyph.split('').join('\n'),
                    textAlign: TextAlign.center,
                    style: HudText.operativa(accent, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: HudText.operativa(c.text, size: 15)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(subtitle!, style: HudText.terminal(c.text2, size: 12)),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(mainAxisSize: MainAxisSize.min, children: actions),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(painter: _HazardStripePainter(accent), size: const Size(double.infinity, 8)),
        ],
      ),
    );
  }
}

class _HazardStripePainter extends CustomPainter {
  _HazardStripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stripeWidth = 10.0;
    final paint = Paint()..color = color.withValues(alpha: 0.6);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final span = size.width + size.height;
    for (var x = -size.height; x < span; x += stripeWidth * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + stripeWidth, 0)
        ..lineTo(x + stripeWidth, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HazardStripePainter oldDelegate) => oldDelegate.color != color;
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The two typographic extremes from hud-tactico §3: condensed operative
/// caps for labels/controls, and monospace for logs/timecodes/readouts.
/// (The Japanese "impacto" display face is deliberately not used here —
/// this app's content is the user's own devlog text, not verdict moments
/// that call for a giant single kanji, so forcing it in would be exactly
/// the "densidad sin jerarquía" antipattern §10 warns against.)
class HudText {
  HudText._();

  static TextStyle operativa(
    Color color, {
    double size = 14,
    FontWeight weight = FontWeight.w700,
  }) =>
      GoogleFonts.barlowCondensed(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: size * 0.02,
      );

  static TextStyle terminal(Color color, {double size = 13}) =>
      GoogleFonts.shareTechMono(color: color, fontSize: size);
}

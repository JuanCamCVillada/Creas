import 'package:flutter/material.dart';

/// HUD Táctico color tokens — CONSOLA (dark) and MODO DÍA (light), per the
/// hud-tactico design system. Values for --panel/--grid/--text-dim/--text-2
/// are the exact color-mix() results the system specifies, computed here
/// since Dart has no color-mix primitive.
class HudColors {
  const HudColors({
    required this.bg,
    required this.panel,
    required this.grid,
    required this.text,
    required this.text2,
    required this.textDim,
    required this.struct,
    required this.sys,
    required this.data,
    required this.data2,
    required this.ok,
    required this.id,
    required this.signal,
    required this.unit,
    required this.contrast,
    required this.deny,
    required this.caution,
  });

  final Color bg;
  final Color panel;
  final Color grid;
  final Color text;
  final Color text2;
  final Color textDim;
  final Color struct;
  final Color sys;
  final Color data;
  final Color data2;
  final Color ok;
  final Color id;
  final Color signal;
  final Color unit;
  final Color contrast;
  final Color deny;
  final Color caution;

  /// CONSOLA — default theme: consumer-facing "control room" dark mode.
  static const consola = HudColors(
    bg: Color(0xFF111827),
    panel: Color(0xFF0F1F35), // color-mix(ink 88%, deep 12%)
    grid: Color(0xFF0D2845), // color-mix(ink 75%, deep 25%)
    text: Color(0xFFF9FAFB),
    text2: Color(0xFFE5E7EB),
    textDim: Color(0xFF868A93), // color-mix(text2 55%, ink 45%)
    struct: Color(0xFF00569E),
    sys: Color(0xFF00B5F8),
    data: Color(0xFF47C5FB),
    data2: Color(0xFF5AA5F0),
    ok: Color(0xFF62CFFE),
    id: Color(0xFFFF8A1F),
    signal: Color(0xFF7CFF3A),
    unit: Color(0xFF8B4DFF),
    contrast: Color(0xFFFF5CE1),
    deny: Color(0xFFFF3B3B),
    caution: Color(0xFFFFC21A),
  );

  /// MODO DÍA — light, flat-technical alternate.
  static const dia = HudColors(
    bg: Color(0xFFF9FAFB),
    panel: Color(0xFFF9FEFD),
    grid: Color(0xFFE5E7EB),
    text: Color(0xFF111827),
    text2: Color(0xFF4B515C), // color-mix(ink 75%, paper 25%)
    textDim: Color(0xFF858991), // color-mix(ink 50%, paper 50%)
    struct: Color(0xFF00569E),
    sys: Color(0xFF00569E),
    data: Color(0xFF00B5F8),
    data2: Color(0xFF47C5FB),
    ok: Color(0xFF00569E),
    id: Color(0xFFB45309),
    signal: Color(0xFF2F7D00),
    unit: Color(0xFF6D28D9),
    contrast: Color(0xFFBE185D),
    deny: Color(0xFFD61F1F),
    caution: Color(0xFFB7791F),
  );
}

/// The three status modes from hud-tactico §7. Applied per-screen or
/// per-element, never globally forced — most of this app stays NOMINAL.
enum HudStatus { nominal, precaucion, emergencia }

extension HudStatusColor on HudStatus {
  /// The accent color a status-driven element (banner, border) should use.
  Color accent(HudColors c) => switch (this) {
        HudStatus.nominal => c.sys,
        HudStatus.precaucion => c.caution,
        HudStatus.emergencia => c.deny,
      };
}

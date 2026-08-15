import 'package:flutter/material.dart';

/// Tokens de color del tema como `ThemeExtension`, para que respondan al
/// tema activo (claro/oscuro) leyéndose por contexto.
///
/// Los campos son 1:1 con los que antes vivían en `AppColors`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.card,
    required this.btn,
    required this.btnHover,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.inkText,
    required this.alert,
    required this.success,
    required this.danger,
    required this.text,
    required this.textMuted,
    required this.paper,
  });

  final Color bg;
  final Color surface;
  final Color card;
  final Color btn;
  final Color btnHover;
  final Color surface2;
  final Color line;
  final Color ink;
  final Color inkText;
  final Color alert;
  final Color success;
  final Color danger;
  final Color text;
  final Color textMuted;
  final Color paper;

  /// Paleta oscura: valores idénticos a los `AppColors` actuales.
  static const dark = AppPalette(
    bg: Color(0xFF140A1F),
    surface: Color(0xFF1F1030),
    card: Color(0xFF271438),
    btn: Color(0xFF1B0929),
    btnHover: Color(0xFF260C3A),
    surface2: Color(0xFF2E1A42),
    line: Color(0x12FFFFFF),
    ink: Color(0xFF64009D),
    inkText: Color(0xFFFFFFFF),
    alert: Color(0xFFE86A4D),
    success: Color(0xFF0CFF00),
    danger: Color(0xFFFF0000),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0x73FFFFFF),
    paper: Color(0xFFFFFFFF),
  );

  /// Paleta clara: fondos blancos, acento morado idéntico, texto oscuro.
  static const light = AppPalette(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F2F8),
    card: Color(0xFFFFFFFF),
    btn: Color(0xFFF5F2F8),
    btnHover: Color(0xFFEDE7F3),
    surface2: Color(0xFFEDE7F3),
    line: Color(0x12000000),
    ink: Color(0xFF64009D),
    inkText: Color(0xFFFFFFFF),
    alert: Color(0xFFE86A4D),
    success: Color(0xFF0CFF00),
    danger: Color(0xFFFF0000),
    text: Color(0xFF1A1024),
    textMuted: Color(0x8C000000), // negro ~55%
    paper: Color(0xFFFFFFFF),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? card,
    Color? btn,
    Color? btnHover,
    Color? surface2,
    Color? line,
    Color? ink,
    Color? inkText,
    Color? alert,
    Color? success,
    Color? danger,
    Color? text,
    Color? textMuted,
    Color? paper,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      btn: btn ?? this.btn,
      btnHover: btnHover ?? this.btnHover,
      surface2: surface2 ?? this.surface2,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      inkText: inkText ?? this.inkText,
      alert: alert ?? this.alert,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      paper: paper ?? this.paper,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      btn: Color.lerp(btn, other.btn, t)!,
      btnHover: Color.lerp(btnHover, other.btnHover, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkText: Color.lerp(inkText, other.inkText, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
    );
  }
}

/// Acceso ergonómico a la paleta del tema activo: `context.palette`.
extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

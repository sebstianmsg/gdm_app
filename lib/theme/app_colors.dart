import 'package:flutter/material.dart';

/// Tokens de color 1:1 con las variables `:root` de `public/css/styles.css`
/// (tema de producción de la app web — dark, acento verde único).
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0B0B0E);
  static const surface = Color(0xFF131318);
  static const card = Color(0xFF1A1A20);
  static const btn = Color(0xFF16161B);
  static const btnHover = Color(0xFF1D1D24);
  static const surface2 = Color(0xFF1D1D24);
  static const line = Color(0x12FFFFFF); // rgba(255,255,255,.07)

  /// `--ink`: verde acento (botones primarios, foco, eyebrow, botón +).
  static const ink = Color(0xFF4FAE84);
  static const inkText = Color(0xFF0D1512); // texto sobre botón primario

  static const alert = Color(0xFFE86A4D);

  static const text = Color(0xFFFFFFFF);
  static const textMuted = Color(0x73FFFFFF); // rgba(255,255,255,.45)
  static const paper = Color(0xFFFFFFFF);
}

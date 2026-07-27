import 'package:flutter/material.dart';

/// Tokens de color 1:1 con las variables `:root` de `public/css/styles.css`
/// (tema de producción de la app web — dark, acento verde único).
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0B0610); // morado muy oscuro, casi negro
  // Superficies de contraste derivadas del secundario `#4C0078`.
  static const surface = Color(0xFF180826);
  static const card = Color(0xFF1F0A30);
  static const btn = Color(0xFF1B0929);
  static const btnHover = Color(0xFF260C3A);
  static const surface2 = Color(0xFF260C3A);
  static const line = Color(0x12FFFFFF); // rgba(255,255,255,.07)

  /// `--ink`: acento morado (botones primarios, foco, eyebrow, botón +).
  static const ink = Color(0xFF64009D); // morado principal
  static const inkText = Color(0xFFFFFFFF); // texto blanco sobre botón primario

  static const alert = Color(0xFFE86A4D);
  static const success = Color(0xFF0CFF00); // verde de confirmación (guardar)
  static const danger = Color(0xFFFF0000); // rojo de cancelar/borrar

  static const text = Color(0xFFFFFFFF);
  static const textMuted = Color(0x73FFFFFF); // rgba(255,255,255,.45)
  static const paper = Color(0xFFFFFFFF);
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  /// Arma el `ThemeData` de un tema a partir de su [palette].
  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final base = ThemeData(useMaterial3: true, brightness: brightness);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: palette.text,
      displayColor: palette.text,
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.bg,
      colorScheme: base.colorScheme.copyWith(
        surface: palette.surface,
        primary: palette.ink,
        error: palette.alert,
      ),
      textTheme: textTheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: palette.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.modal),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: palette.ink, width: 2),
        ),
        hintStyle: TextStyle(color: palette.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.ink,
          foregroundColor: palette.inkText,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.smallButton),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          side: BorderSide(color: palette.ink),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.smallButton),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.textMuted),
      ),
      dividerTheme: DividerThemeData(color: palette.line, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.card,
        contentTextStyle: TextStyle(color: palette.text),
        actionTextColor: palette.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
    );
  }
}

/// Estilos de texto puntuales que no mapean a un rol estándar de Material
/// (eyebrow, labels de sección uppercase, total del mes, etc).
///
/// El color se resuelve en el punto de uso con el token del tema activo
/// (ver `AppTextStyles.<x>(context)`), para que reaccionen al tema.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle eyebrow(BuildContext context) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6, // ~0.14em
        color: context.palette.text,
      );

  static TextStyle h1(BuildContext context) => GoogleFonts.inter(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: context.palette.text,
      );

  static TextStyle sectionLabel(BuildContext context) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: context.palette.textMuted,
      );

  static TextStyle total(BuildContext context) => GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: context.palette.text,
      );

  static TextStyle amount(BuildContext context) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.palette.text,
      );

  static TextStyle description(BuildContext context) => GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: context.palette.text,
      );

  static TextStyle muted(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.palette.textMuted,
      );
}

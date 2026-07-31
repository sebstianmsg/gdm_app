import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave del tema elegido en `SharedPreferences`. Ausente ⇒ oscuro.
const String kThemeModeKey = 'theme_mode';

/// Serializa/parsea el `ThemeMode` a los valores persistidos (`'light'`/
/// `'dark'`). Solo se contemplan claro y oscuro explícitos (sin "sistema").
ThemeMode themeModeFromString(String? value) =>
    value == 'light' ? ThemeMode.light : ThemeMode.dark;

String themeModeToString(ThemeMode mode) =>
    mode == ThemeMode.light ? 'light' : 'dark';

/// Valor inicial del tema, leído desde `SharedPreferences` antes de `runApp`
/// (ver `main.dart`) para pintar el primer frame con el tema correcto.
/// Se **sobrescribe** en el `ProviderScope`; sin override, default oscuro.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.dark);

/// Estado del tema activo. Persiste cada cambio en `SharedPreferences`.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial);

  /// Alterna entre claro y oscuro.
  void toggle() =>
      setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  /// Fija el modo indicado y lo persiste.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeModeKey, themeModeToString(mode));
  }
}

final themeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(initialThemeModeProvider)),
);

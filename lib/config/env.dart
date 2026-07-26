/// Configuración de entorno de la app.
///
/// Las credenciales de Supabase se definen en build/run time con `--dart-define`:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
///
/// Este archivo es el único punto de lectura de configuración de la app.
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Falla temprano y con un mensaje claro si falta alguna variable, en vez de
  /// dejar que `Supabase.initialize` explote con una URL/key vacía en runtime.
  static void assertValid() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Faltan variables de entorno: ${missing.join(', ')}. '
        'Pasalas con --dart-define al correr la app, por ejemplo:\n'
        '  flutter run '
        '--dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co '
        '--dart-define=SUPABASE_ANON_KEY=tu_anon_key',
      );
    }
  }
}

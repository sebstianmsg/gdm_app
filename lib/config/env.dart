/// Configuración de entorno de la app.
///
/// La URL base del backend se define en build/run time con:
///   flutter run --dart-define=API_BASE_URL=https://tu-servicio.onrender.com
///
/// Sin especificar, apunta a `10.0.2.2:3000`, que es cómo el emulador Android
/// ve el `localhost` de la máquina host (útil para desarrollar contra el
/// backend Express corriendo localmente con `npm start`).
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}

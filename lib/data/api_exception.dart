/// Excepción de la capa de API: envuelve el `{ "error": "<mensaje>" }`
/// que devuelve el backend, o un mensaje genérico si no hay respuesta.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

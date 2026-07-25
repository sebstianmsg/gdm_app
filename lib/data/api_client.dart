import 'package:dio/dio.dart';

import '../config/env.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Cliente HTTP compartido por toda la app.
///
/// - Inyecta `Authorization: Bearer <token>` en cada request (salvo login).
/// - Timeouts largos: el free tier de Render hace spin-down y la primera
///   request tras inactividad puede tardar 30-60s en responder.
/// - Ante un 401 de cualquier endpoint, dispara [onUnauthorized] (la app lo
///   usa para limpiar la sesión y volver a la pantalla de login), igual que
///   `apiGet`/`apiSend` hacen en `public/js/app.js`.
class ApiClient {
  ApiClient({required TokenStorage tokenStorage, Dio? dio})
    : _tokenStorage = tokenStorage,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              contentType: 'application/json',
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Callback invocado cuando el backend responde 401. Lo setea el provider
  /// de auth para limpiar el token y volver al gate de login.
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _request(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _request(() => _dio.post(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _request(() => _dio.put(path, data: body));

  /// DELETE del backend siempre exige `{confirmed:true}` en el body y
  /// responde 204 sin contenido.
  Future<void> delete(String path, {Object? body}) async {
    await _request(() => _dio.delete(path, data: body));
  }

  Future<dynamic> _request(Future<Response<dynamic>> Function() send) async {
    try {
      final response = await send();
      return response.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String message;
    if (data is Map && data['error'] is String) {
      message = data['error'] as String;
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      message = 'El servidor no respondió a tiempo. Puede estar reactivándose, probá de nuevo.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No se pudo conectar al servidor.';
    } else {
      message = 'Ocurrió un error inesperado.';
    }
    return ApiException(message, statusCode: status);
  }
}

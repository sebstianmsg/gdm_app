import '../models/session.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// POST /api/auth/login — sin auth. 401 "Credenciales inválidas",
  /// 429 si se excede el rate limit del backend.
  Future<Session> login({required String email, required String password}) async {
    final data = await _client.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    return Session.fromJson(data as Map<String, dynamic>);
  }
}

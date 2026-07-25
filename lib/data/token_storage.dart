import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persiste el access token JWT de forma segura.
/// Equivalente al `localStorage['gdm_token']` de la app web (`public/js/app.js`).
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'gdm_token';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_exception.dart';
import '../../data/auth_api.dart';
import '../../data/token_storage.dart';
import '../../providers/core_providers.dart';

enum AuthStatus { bootstrapping, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.isSubmitting = false,
    this.error,
  });

  final AuthStatus status;
  final bool isSubmitting;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) => AuthState(
    status: status ?? this.status,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Sesión "optimista", igual que el frontend web: si hay token guardado se
/// asume válido hasta que el backend lo rechace con un 401 (no hay endpoint
/// de refresh ni chequeo local de `expiresAt`).
class AuthNotifier extends Notifier<AuthState> {
  late final AuthApi _authApi;
  late final TokenStorage _tokenStorage;

  @override
  AuthState build() {
    _authApi = ref.watch(authApiProvider);
    _tokenStorage = ref.watch(tokenStorageProvider);
    _bootstrap();
    return const AuthState(status: AuthStatus.bootstrapping);
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.readToken();
    state = AuthState(
      status: (token != null && token.isNotEmpty)
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final session = await _authApi.login(email: email, password: password);
      await _tokenStorage.saveToken(session.accessToken);
      state = const AuthState(status: AuthStatus.authenticated);
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Ocurrió un error inesperado.',
      );
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Invocado por el `ApiClient` cuando cualquier request responde 401.
  void forceLogout() {
    _tokenStorage.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

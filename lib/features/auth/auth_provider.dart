import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Auth apoyada 100% en `supabase_flutter`: el SDK persiste la sesión entre
/// reinicios y emite cambios por `onAuthStateChange`. No hay storage manual de
/// tokens ni chequeo local de expiración.
class AuthNotifier extends Notifier<AuthState> {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  AuthState build() {
    // Reaccionar a cambios de sesión del SDK (login, logout, refresh, expiración).
    final sub = _auth.onAuthStateChange.listen((data) {
      final hasSession = data.session != null;
      // Preservar isSubmitting/error mientras hay un login en curso sin sesión.
      if (!hasSession && state.isSubmitting) return;
      state = AuthState(
        status: hasSession
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
      );
    });
    ref.onDispose(sub.cancel);

    // Estado inicial según la sesión ya restaurada por el SDK.
    return AuthState(
      status: _auth.currentSession != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _auth.signInWithPassword(email: email, password: password);
      state = const AuthState(status: AuthStatus.authenticated);
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Ocurrió un error inesperado.',
      );
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

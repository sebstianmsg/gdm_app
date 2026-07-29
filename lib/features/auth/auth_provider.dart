import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';

/// Clave del flag "Recordarme" en `SharedPreferences`. Ausente ⇒ `false`.
const String kRememberMeKey = 'remember_me';

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

  /// Emite cuando llega un deep link de recuperación (`passwordRecovery`), para
  /// que la UI enrute a `reset_password_screen` sin navegar al home. Se resuelve
  /// consumiendo el stream desde `_AuthGate` (ver Paso 8).
  Stream<void> get onPasswordRecovery => _passwordRecovery.stream;
  final _passwordRecovery = StreamController<void>.broadcast();

  @override
  AuthState build() {
    ref.onDispose(_passwordRecovery.close);
    // Reaccionar a cambios de sesión del SDK (login, logout, refresh, expiración).
    final sub = _auth.onAuthStateChange.listen((data) {
      // El deep link de reset trae sesión (de recovery) pero NO debe navegar al
      // home: lo señalizamos aparte y no tocamos el estado autenticado.
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecovery.add(null);
        return;
      }
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

  Future<void> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _auth.signInWithPassword(email: email, password: password);
      // Persistir la preferencia antes de marcar autenticado: el chequeo de
      // "Recordarme" al arranque lee esta clave para decidir si desloguear.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kRememberMeKey, rememberMe);
      state = const AuthState(status: AuthStatus.authenticated);
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, error: _mapAuthError(e));
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Ocurrió un error inesperado.',
      );
    }
  }

  /// Alta por email. El nombre queda en `user_metadata.full_name` y el
  /// `emailRedirectTo` es el deep link que confirma la cuenta y abre la app.
  /// No deja sesión iniciada: el usuario debe confirmar el email primero.
  Future<void> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
        emailRedirectTo: 'com.gdmapp://login-callback',
      );
      // Alta ok pero sin sesión (falta confirmar). Volvemos a un estado no
      // autenticado y sin submitting; la UI muestra "revisá tu email".
      state = state.copyWith(isSubmitting: false, clearError: true);
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, error: _mapAuthError(e));
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Ocurrió un error inesperado.',
      );
    }
  }

  /// Login nativo con Google: abre la hoja de cuenta, obtiene el `idToken` y lo
  /// canjea en Supabase con `signInWithIdToken`. Google siempre persiste
  /// (no aplica "Recordarme").
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: Env.googleServerClientId,
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        // El usuario canceló la hoja de Google: sin error, sin cambio.
        state = state.copyWith(isSubmitting: false);
        return;
      }
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null) {
        state = state.copyWith(
          isSubmitting: false,
          error: 'No se pudo obtener el token de Google. Revisá la config.',
        );
        return;
      }
      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      // Google siempre persiste: marcamos remember_me para no desloguear al
      // arranque.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kRememberMeKey, true);
      state = const AuthState(status: AuthStatus.authenticated);
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, error: _mapAuthError(e));
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'No se pudo iniciar sesión con Google.',
      );
    }
  }

  /// Envía el email de recuperación con el deep link de reset.
  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.gdmapp://reset-password',
      );
      state = state.copyWith(isSubmitting: false, clearError: true);
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, error: _mapAuthError(e));
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Ocurrió un error inesperado.',
      );
    }
  }

  /// Fija la nueva contraseña sobre la sesión de recovery abierta por el deep
  /// link de reset.
  Future<void> updatePassword(String newPassword) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
      state = const AuthState(status: AuthStatus.authenticated);
    } on AuthException catch (e) {
      state = state.copyWith(isSubmitting: false, error: _mapAuthError(e));
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

  /// Traduce errores comunes de Supabase a mensajes legibles en español.
  String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('email not confirmed')) {
      return 'Confirmá tu email antes de iniciar sesión.';
    }
    if (msg.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (msg.contains('already registered') ||
        msg.contains('already been registered')) {
      return 'Ese email ya está registrado.';
    }
    return e.message;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

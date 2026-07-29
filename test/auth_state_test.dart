// Tests de las transiciones de estado que usan los métodos del AuthNotifier
// (login, signUpWithEmail, signInWithGoogle, sendPasswordReset,
// updatePassword). Cada método arranca marcando isSubmitting y limpiando el
// error, y termina en autenticado (éxito) o con isSubmitting=false + error
// (fallo). Ese contrato vive en AuthState.copyWith y se cubre acá sin depender
// del SDK de Supabase (los flujos externos quedan fuera de alcance por spec).

import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/auth/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('isAuthenticated refleja el status', () {
      expect(
        const AuthState(status: AuthStatus.authenticated).isAuthenticated,
        isTrue,
      );
      expect(
        const AuthState(status: AuthStatus.unauthenticated).isAuthenticated,
        isFalse,
      );
    });

    test('inicio de una acción: isSubmitting=true y limpia error previo', () {
      const withError = AuthState(
        status: AuthStatus.unauthenticated,
        error: 'algo falló',
      );

      final submitting = withError.copyWith(
        isSubmitting: true,
        clearError: true,
      );

      expect(submitting.isSubmitting, isTrue);
      expect(submitting.error, isNull);
      expect(submitting.status, AuthStatus.unauthenticated);
    });

    test('fallo: isSubmitting=false y setea error legible', () {
      const submitting = AuthState(
        status: AuthStatus.unauthenticated,
        isSubmitting: true,
      );

      final failed = submitting.copyWith(
        isSubmitting: false,
        error: 'Email o contraseña incorrectos.',
      );

      expect(failed.isSubmitting, isFalse);
      expect(failed.error, 'Email o contraseña incorrectos.');
      expect(failed.isAuthenticated, isFalse);
    });

    test('éxito: estado autenticado limpio (sin submitting ni error)', () {
      const authenticated = AuthState(status: AuthStatus.authenticated);

      expect(authenticated.isAuthenticated, isTrue);
      expect(authenticated.isSubmitting, isFalse);
      expect(authenticated.error, isNull);
    });

    test('clearError tiene prioridad sobre un error pasado en el mismo copyWith',
        () {
      const base = AuthState(status: AuthStatus.unauthenticated);

      final cleared = base.copyWith(error: 'x', clearError: true);

      expect(cleared.error, isNull);
    });

    test('copyWith sin argumentos preserva los campos', () {
      const base = AuthState(
        status: AuthStatus.unauthenticated,
        isSubmitting: true,
        error: 'e',
      );

      final same = base.copyWith();

      expect(same.status, base.status);
      expect(same.isSubmitting, base.isSubmitting);
      expect(same.error, base.error);
    });
  });
}

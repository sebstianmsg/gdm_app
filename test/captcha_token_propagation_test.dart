// Verifica que AuthNotifier propaga el `captchaToken` que recibe hacia las
// llamadas del SDK de Supabase (spec 22), usando un doble inyectado del
// GoTrueClient. No toca la red ni el SDK real: el fake captura el token con
// que se lo invoca.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:gdm_app/features/auth/auth_provider.dart';

/// Doble del cliente de auth que solo implementa los tres métodos que el spec
/// cubre; el resto queda en `noSuchMethod`. Guarda el `captchaToken` recibido.
class _CapturingAuth implements supa.GoTrueClient {
  String? signInCaptchaToken;
  String? signUpCaptchaToken;
  String? resetCaptchaToken;

  @override
  Stream<supa.AuthState> get onAuthStateChange => const Stream.empty();

  @override
  supa.Session? get currentSession => null;

  @override
  Future<supa.AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    signInCaptchaToken = captchaToken;
    return supa.AuthResponse();
  }

  @override
  Future<supa.AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    supa.OtpChannel channel = supa.OtpChannel.sms,
  }) async {
    signUpCaptchaToken = captchaToken;
    return supa.AuthResponse();
  }

  @override
  Future<void> resetPasswordForEmail(
    String email, {
    String? redirectTo,
    String? captchaToken,
  }) async {
    resetCaptchaToken = captchaToken;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CapturingAuth fakeAuth;
  late ProviderContainer container;

  setUp(() {
    // `login` persiste el flag "Recordarme" en SharedPreferences.
    SharedPreferences.setMockInitialValues({});
    fakeAuth = _CapturingAuth();
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthNotifier(authClient: fakeAuth),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('login propaga el captchaToken a signInWithPassword', () async {
    await container
        .read(authProvider.notifier)
        .login('user@mail.com', 'secret', captchaToken: 'tok-login');

    expect(fakeAuth.signInCaptchaToken, 'tok-login');
  });

  test('signUpWithEmail propaga el captchaToken a signUp', () async {
    await container.read(authProvider.notifier).signUpWithEmail(
          'Sebas',
          'user@mail.com',
          'secret',
          captchaToken: 'tok-signup',
        );

    expect(fakeAuth.signUpCaptchaToken, 'tok-signup');
  });

  test('sendPasswordReset propaga el captchaToken a resetPasswordForEmail',
      () async {
    await container
        .read(authProvider.notifier)
        .sendPasswordReset('user@mail.com', captchaToken: 'tok-reset');

    expect(fakeAuth.resetCaptchaToken, 'tok-reset');
  });
}

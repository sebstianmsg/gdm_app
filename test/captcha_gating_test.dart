// Verifica el gating del captcha (spec 22): en registro, login y
// forgot-password el botón de envío está deshabilitado mientras no haya token
// y se habilita al resolver el captcha.
//
// `flutter_turnstile` monta un WebView que no tiene plataforma en `flutter
// test`, así que se reemplaza por un stub vía `CaptchaField.debugBuilder`: un
// botón que, al tocarse, emite un token como haría Turnstile al resolverse.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/auth/auth_provider.dart';
import 'package:gdm_app/features/auth/captcha_field.dart';
import 'package:gdm_app/features/auth/forgot_password_screen.dart';
import 'package:gdm_app/features/auth/login_screen.dart';
import 'package:gdm_app/features/auth/signup_screen.dart';
import 'package:gdm_app/theme/app_theme.dart';

/// Fake sin sesión: evita inicializar el SDK real de Supabase en el test.
class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

const _solveKey = Key('stub-solve-captcha');

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(_FakeAuthNotifier.new)],
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
  );
  // El fondo del login anima infinito: pump() (no pumpAndSettle) alcanza.
  await tester.pump();
}

void main() {
  setUp(() {
    // Stub que reemplaza el WebView: al tocarlo, emite un token válido.
    CaptchaField.debugBuilder = (context, field) => ElevatedButton(
          key: _solveKey,
          onPressed: () => field.onToken('stub-token'),
          child: const Text('resolver captcha'),
        );
  });

  tearDown(() => CaptchaField.debugBuilder = null);

  Future<void> expectGating(
    WidgetTester tester,
    String buttonLabel,
  ) async {
    ElevatedButton button() => tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, buttonLabel),
        );

    // Sin token: deshabilitado.
    expect(button().onPressed, isNull, reason: 'sin token debe estar off');

    // Resolver el captcha (emite token) → se habilita.
    await tester.tap(find.byKey(_solveKey));
    await tester.pump();

    expect(button().onPressed, isNotNull, reason: 'con token debe habilitarse');
  }

  testWidgets('login: botón bloqueado sin token, habilitado con token',
      (tester) async {
    await _pumpScreen(tester, const LoginScreen());
    await expectGating(tester, 'Iniciar sesión');
  });

  testWidgets('registro: botón bloqueado sin token, habilitado con token',
      (tester) async {
    await _pumpScreen(tester, const SignupScreen());
    await expectGating(tester, 'Crear cuenta');
  });

  testWidgets('forgot-password: botón bloqueado sin token, habilitado con token',
      (tester) async {
    await _pumpScreen(tester, const ForgotPasswordScreen());
    await expectGating(tester, 'Enviar link');
  });
}

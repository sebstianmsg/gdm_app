// Smoke test: sin sesión, la app debe arrancar mostrando el login
// (equivalente a `boot()` -> `showGate()` en public/js/app.js).
//
// Se sobreescribe `authProvider` con un fake que reporta `unauthenticated`,
// así el test no depende de inicializar el SDK de Supabase (que usa canales
// nativos no disponibles en `flutter test`).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/auth/auth_provider.dart';
import 'package:gdm_app/main.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

void main() {
  testWidgets('Muestra la pantalla de login al arrancar sin sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthNotifier.new),
        ],
        child: const GdmApp(),
      ),
    );
    // El login tiene un fondo con animación infinita (AnimatedLoginBackground),
    // por lo que `pumpAndSettle()` nunca terminaría. Un `pump()` basta para
    // construir el primer frame y verificar que aparece el login.
    await tester.pump();

    // Aparece dos veces: el título de la tarjeta y el label del botón.
    expect(find.text('Iniciar sesión'), findsWidgets);
  });
}

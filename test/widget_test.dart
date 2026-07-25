// Smoke test: sin token guardado, la app debe arrancar mostrando el login
// (equivalente a `boot()` -> `showGate()` en public/js/app.js).
//
// Se sobreescribe `tokenStorageProvider` con un fake en memoria: el plugin
// real (`flutter_secure_storage`) usa un MethodChannel que no responde en
// `flutter test` sin un host nativo.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/data/token_storage.dart';
import 'package:gdm_app/main.dart';
import 'package:gdm_app/providers/core_providers.dart';

class _FakeTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<void> clearToken() async => _token = null;
}

void main() {
  testWidgets('Muestra la pantalla de login al arrancar sin sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: const GdmApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Aparece dos veces: el título de la tarjeta y el label del botón.
    expect(find.text('Iniciar sesión'), findsWidgets);
  });
}

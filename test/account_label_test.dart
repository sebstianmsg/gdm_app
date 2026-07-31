// Tests del helper `accountLabel`, que resuelve el identificador de la cuenta
// mostrado en el header de la pantalla principal (spec 10).

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gdm_app/features/month/home_screen.dart';

/// Construye un `User` mínimo para pruebas, con el `email` y el
/// `user_metadata` que interesan a la cascada.
User _user({String? email, Map<String, dynamic>? metadata}) {
  return User(
    id: 'test-id',
    appMetadata: const {},
    userMetadata: metadata,
    aud: 'authenticated',
    email: email,
    createdAt: DateTime(2026).toIso8601String(),
  );
}

void main() {
  group('accountLabel', () {
    test('usa full_name cuando está presente', () {
      final user = _user(
        email: 'sebastianmsg@outlook.com',
        metadata: {'full_name': 'Sebastián Suárez'},
      );
      expect(accountLabel(user), 'Sebastián Suárez');
    });

    test('usa name (típico de Google) cuando no hay full_name', () {
      final user = _user(
        email: 'sebastianmsg@outlook.com',
        metadata: {'name': 'Sebastián G'},
      );
      expect(accountLabel(user), 'Sebastián G');
    });

    test('usa la parte previa al @ cuando no hay nombre', () {
      final user = _user(email: 'sebastianmsg@outlook.com');
      expect(accountLabel(user), 'sebastianmsg');
    });

    test('email sin @ se muestra completo', () {
      final user = _user(email: 'sinarroba');
      expect(accountLabel(user), 'sinarroba');
    });

    test('usuario nulo devuelve cadena vacía', () {
      expect(accountLabel(null), '');
    });

    test('full_name vacío cae a name y luego a email', () {
      final user = _user(
        email: 'sebastianmsg@outlook.com',
        metadata: {'full_name': '   ', 'name': ''},
      );
      expect(accountLabel(user), 'sebastianmsg');
    });
  });
}

// Tests de las validaciones de formularios de auth (login, signup, forgot,
// reset), centralizadas en AuthValidators.

import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/auth/auth_validators.dart';

void main() {
  group('AuthValidators.name', () {
    test('nombre vacío o solo espacios es inválido', () {
      expect(AuthValidators.name(null), isNotNull);
      expect(AuthValidators.name(''), isNotNull);
      expect(AuthValidators.name('   '), isNotNull);
    });

    test('nombre con contenido es válido', () {
      expect(AuthValidators.name('Ada'), isNull);
    });
  });

  group('AuthValidators.email', () {
    test('email vacío o mal formado es inválido', () {
      expect(AuthValidators.email(null), isNotNull);
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('no-es-un-email'), isNotNull);
      expect(AuthValidators.email('falta@dominio'), isNotNull);
      expect(AuthValidators.email('@dominio.com'), isNotNull);
    });

    test('email bien formado es válido (con espacios recortados)', () {
      expect(AuthValidators.email('user@example.com'), isNull);
      expect(AuthValidators.email('  user.name+tag@sub.example.com  '), isNull);
    });
  });

  group('AuthValidators.password', () {
    test('vacía o más corta que el mínimo es inválida', () {
      expect(AuthValidators.password(null), isNotNull);
      expect(AuthValidators.password(''), isNotNull);
      expect(AuthValidators.password('12345'), isNotNull);
    });

    test('con el largo mínimo es válida', () {
      expect(
        AuthValidators.password('a' * AuthValidators.minPasswordLength),
        isNull,
      );
    });
  });

  group('AuthValidators.confirmPassword', () {
    test('vacía es inválida', () {
      expect(AuthValidators.confirmPassword(null, 'secret1'), isNotNull);
      expect(AuthValidators.confirmPassword('', 'secret1'), isNotNull);
    });

    test('distinta del original es inválida', () {
      expect(AuthValidators.confirmPassword('otra', 'secret1'), isNotNull);
    });

    test('igual al original es válida', () {
      expect(AuthValidators.confirmPassword('secret1', 'secret1'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/utils/voice_expense_parser.dart';

void main() {
  group('parseVoiceExpense', () {
    test('frase típica: monto, descripción sin monto/pesos y categoría', () {
      final result = parseVoiceExpense('gasté 3000 pesos en el súper');

      expect(result.amount, 3000);
      expect(result.categoryName, 'Almacén');
      expect(result.description, isNotNull);
      expect(result.description, isNot(contains('3000')));
      expect(result.description!.toLowerCase(), isNot(contains('pesos')));
      expect(result.description, contains('súper'));
    });

    test('tolera separador de miles con punto (3.000 → 3000)', () {
      final result = parseVoiceExpense('pagué 3.000 en la farmacia');

      expect(result.amount, 3000);
      expect(result.categoryName, 'Salud');
    });

    test('tolera decimal con coma (1500,50 → 1500.5)', () {
      final result = parseVoiceExpense('gasté 1500,50 en nafta');

      expect(result.amount, 1500.5);
      expect(result.categoryName, 'Transporte');
    });

    test('tolera el símbolo \$ y lo quita de la descripción', () {
      final result = parseVoiceExpense('\$2500 de netflix');

      expect(result.amount, 2500);
      expect(result.categoryName, 'Servicios');
      expect(result.description, isNot(contains('\$')));
    });

    test('sin monto: amount null pero descripción y categoría presentes', () {
      final result = parseVoiceExpense('cine con amigos');

      expect(result.amount, isNull);
      expect(result.categoryName, 'Ocio');
      expect(result.description, contains('cine'));
    });

    test('sin keyword de categoría: categoryName null', () {
      final result = parseVoiceExpense('compré 500 de cosas varias');

      expect(result.amount, 500);
      expect(result.categoryName, isNull);
    });

    test('toma el primer número de la frase', () {
      final result = parseVoiceExpense('3 paquetes de 500 pesos');

      expect(result.amount, 3);
    });

    test('nunca lanza con frase vacía', () {
      final result = parseVoiceExpense('');

      expect(result.amount, isNull);
      expect(result.description, isNull);
      expect(result.categoryName, isNull);
    });
  });
}

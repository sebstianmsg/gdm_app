// Tests de mapeo de modelos (snake_case de Postgres ↔ camelCase de Dart) y del
// parseo defensivo de `amount` (columna `numeric`).

import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/models/category.dart';
import 'package:gdm_app/models/expense.dart';

void main() {
  group('Category.fromJson', () {
    test('mapea is_deletable (snake_case) a isDeletable', () {
      final c = Category.fromJson({
        'id': 'cat-1',
        'name': 'Comida',
        'color': '#FFD93D',
        'is_deletable': true,
      });
      expect(c.id, 'cat-1');
      expect(c.name, 'Comida');
      expect(c.color, '#FFD93D');
      expect(c.isDeletable, isTrue);
    });

    test('respeta is_deletable = false ("Otros")', () {
      final c = Category.fromJson({
        'id': 'cat-otros',
        'name': 'Otros',
        'color': '#FF9A3C',
        'is_deletable': false,
      });
      expect(c.isDeletable, isFalse);
    });
  });

  group('Expense.fromJson', () {
    test('mapea category_id (snake_case) y parsea la fecha', () {
      final e = Expense.fromJson({
        'id': 'exp-1',
        'description': 'Café',
        'amount': 1500,
        'date': '2026-07-26',
        'category_id': 'cat-1',
      });
      expect(e.id, 'exp-1');
      expect(e.description, 'Café');
      expect(e.categoryId, 'cat-1');
      expect(e.date, DateTime(2026, 7, 26));
    });

    test('amount como int se convierte a double', () {
      final e = Expense.fromJson({
        'id': 'exp-2',
        'description': 'x',
        'amount': 1500,
        'date': '2026-07-01',
        'category_id': 'cat-1',
      });
      expect(e.amount, 1500.0);
      expect(e.amount, isA<double>());
    });

    test('amount como String (numeric de Postgres) se parsea a double', () {
      final e = Expense.fromJson({
        'id': 'exp-3',
        'description': 'x',
        'amount': '1234.56',
        'date': '2026-07-01',
        'category_id': 'cat-1',
      });
      expect(e.amount, 1234.56);
    });

    test('toCreateJson emite category_id (snake_case) y date formateada', () {
      final e = Expense(
        id: 'exp-4',
        description: 'Nafta',
        amount: 9000.0,
        date: DateTime(2026, 1, 5),
        categoryId: 'cat-transp',
      );
      final json = e.toCreateJson();
      expect(json['category_id'], 'cat-transp');
      expect(json['date'], '2026-01-05');
      expect(json.containsKey('categoryId'), isFalse);
    });
  });

  group('formatDateEs', () {
    test('formatea día/mes/año', () {
      expect(formatDateEs(DateTime(2026, 7, 26)), '26/07/2026');
    });

    test('día y mes con cero a la izquierda', () {
      expect(formatDateEs(DateTime(2026, 12, 5)), '05/12/2026');
    });
  });

  group('parseAmount', () {
    test('acepta num y String', () {
      expect(parseAmount(10), 10.0);
      expect(parseAmount(10.5), 10.5);
      expect(parseAmount('42.75'), 42.75);
    });

    test('lanza FormatException ante valores inválidos', () {
      expect(() => parseAmount('abc'), throwsFormatException);
      expect(() => parseAmount(null), throwsFormatException);
    });
  });
}

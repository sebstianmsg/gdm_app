// Tests de mapeo de modelos (snake_case de Postgres ↔ camelCase de Dart) y del
// parseo defensivo de `amount` (columna `numeric`).

import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/models/category.dart';
import 'package:gdm_app/models/expense.dart';
import 'package:gdm_app/models/partnership.dart';
import 'package:gdm_app/models/partner_invite.dart';
import 'package:gdm_app/models/shared_expense.dart';

void main() {
  group('Category.fromJson', () {
    test('mapea is_deletable (snake_case) a isDeletable', () {
      final c = Category.fromJson({
        'id': 'cat-1',
        'name': 'Comida',
        'color': '#FFD93D',
        'icon': 'fork',
        'is_deletable': true,
      });
      expect(c.id, 'cat-1');
      expect(c.name, 'Comida');
      expect(c.color, '#FFD93D');
      expect(c.icon, 'fork');
      expect(c.isDeletable, isTrue);
    });

    test('icon ausente cae en el fallback "help"', () {
      final c = Category.fromJson({
        'id': 'cat-2',
        'name': 'Vieja',
        'color': '#000000',
        'is_deletable': true,
      });
      expect(c.icon, 'help');
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

  group('Partnership.fromJson / partnerName', () {
    Map<String, dynamic> row({Object? unlinkedAt}) => {
      'id': 'p-1',
      'user_low': 'aaa',
      'user_high': 'zzz',
      'user_low_name': 'Ana',
      'user_high_name': 'Zoe',
      'unlinked_at': unlinkedAt,
    };

    test('mapea snake_case y unlinked_at null => activo', () {
      final p = Partnership.fromJson(row());
      expect(p.id, 'p-1');
      expect(p.userLow, 'aaa');
      expect(p.userHighName, 'Zoe');
      expect(p.unlinkedAt, isNull);
      expect(p.isActive, isTrue);
    });

    test('unlinked_at no-nulo => archivado', () {
      final p = Partnership.fromJson(row(unlinkedAt: '2026-08-01T10:00:00Z'));
      expect(p.isActive, isFalse);
      expect(p.unlinkedAt, isNotNull);
    });

    test('partnerName devuelve el nombre de la otra persona según "me"', () {
      final p = Partnership.fromJson(row());
      expect(p.partnerName('aaa'), 'Zoe'); // soy user_low
      expect(p.partnerName('zzz'), 'Ana'); // soy user_high
    });
  });

  group('PartnerInvite.fromJson', () {
    test('mapea snake_case y pendiente vigente', () {
      final future = DateTime.now().add(const Duration(days: 7));
      final i = PartnerInvite.fromJson({
        'id': 'inv-1',
        'code': 'ABCD2345',
        'inviter_id': 'aaa',
        'inviter_name': 'Ana',
        'expires_at': future.toIso8601String(),
        'consumed_at': null,
      });
      expect(i.code, 'ABCD2345');
      expect(i.inviterName, 'Ana');
      expect(i.isPending, isTrue);
    });

    test('consumido no está pendiente', () {
      final future = DateTime.now().add(const Duration(days: 7));
      final i = PartnerInvite.fromJson({
        'id': 'inv-2',
        'code': 'XXXX2345',
        'inviter_id': 'aaa',
        'inviter_name': 'Ana',
        'expires_at': future.toIso8601String(),
        'consumed_at': '2026-08-02T00:00:00Z',
      });
      expect(i.isPending, isFalse);
    });

    test('vencido no está pendiente', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final i = PartnerInvite.fromJson({
        'id': 'inv-3',
        'code': 'YYYY2345',
        'inviter_id': 'aaa',
        'inviter_name': 'Ana',
        'expires_at': past.toIso8601String(),
        'consumed_at': null,
      });
      expect(i.isPending, isFalse);
    });
  });

  group('SharedExpense.fromJson / toJson', () {
    test('mapea snake_case y parsea fecha/monto', () {
      final s = SharedExpense.fromJson({
        'id': 's-1',
        'partnership_id': 'p-1',
        'description': 'Súper',
        'amount': '1234.56',
        'date': '2026-08-03',
        'paid_by': 'aaa',
        'created_by': 'zzz',
      });
      expect(s.id, 's-1');
      expect(s.partnershipId, 'p-1');
      expect(s.amount, 1234.56);
      expect(s.date, DateTime(2026, 8, 3));
      expect(s.paidBy, 'aaa');
      expect(s.createdBy, 'zzz');
    });

    test('toCreateJson emite snake_case con date formateada', () {
      final s = SharedExpense(
        id: 's-2',
        partnershipId: 'p-1',
        description: 'Cena',
        amount: 8000,
        date: DateTime(2026, 1, 5),
        paidBy: 'aaa',
        createdBy: 'aaa',
      );
      final json = s.toCreateJson();
      expect(json['partnership_id'], 'p-1');
      expect(json['paid_by'], 'aaa');
      expect(json['created_by'], 'aaa');
      expect(json['date'], '2026-01-05');
      expect(json.containsKey('paidBy'), isFalse);
    });
  });
}

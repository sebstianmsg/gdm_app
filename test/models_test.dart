// Tests de mapeo de modelos (snake_case de Postgres ↔ camelCase de Dart) y del
// parseo defensivo de `amount` (columna `numeric`).

import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/models/category.dart';
import 'package:gdm_app/models/expense.dart';
import 'package:gdm_app/models/partnership.dart';
import 'package:gdm_app/models/partner_invite.dart';
import 'package:gdm_app/models/shared_expense.dart';
import 'package:gdm_app/models/bill_reminder.dart';

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

  group('BillReminder.fromJson / toJson', () {
    Map<String, dynamic> row({
      Object? amount = '1500.00',
      String kind = 'service',
      int startDay = 10,
      Object? paidCycle,
      bool active = true,
    }) => {
      'id': 'br-1',
      'name': 'Luz',
      'kind': kind,
      'amount': amount,
      'category_id': 'cat-serv',
      'start_day': startDay,
      'due_day': 15,
      'notify_hour': 9,
      'notify_minute': 30,
      'persistent': true,
      'repeat_monthly': true,
      'paid_cycle': paidCycle,
      'active': active,
    };

    test('mapea snake_case, parsea monto y kind', () {
      final r = BillReminder.fromJson(row());
      expect(r.id, 'br-1');
      expect(r.name, 'Luz');
      expect(r.kind, ReminderKind.service);
      expect(r.amount, 1500.0);
      expect(r.categoryId, 'cat-serv');
      expect(r.startDay, 10);
      expect(r.dueDay, 15);
      expect(r.notifyHour, 9);
      expect(r.notifyMinute, 30);
      expect(r.persistent, isTrue);
      expect(r.repeatMonthly, isTrue);
      expect(r.paidCycle, isNull);
      expect(r.active, isTrue);
    });

    test('mapea kinds card y debt', () {
      expect(BillReminder.fromJson(row(kind: 'card')).kind, ReminderKind.card);
      expect(BillReminder.fromJson(row(kind: 'debt')).kind, ReminderKind.debt);
    });

    test('kind inválido lanza FormatException', () {
      expect(() => BillReminder.fromJson(row(kind: 'x')), throwsFormatException);
    });

    test('toCreateJson emite snake_case sin id/paid_cycle/active', () {
      final r = BillReminder.fromJson(row());
      final json = r.toCreateJson();
      expect(json['name'], 'Luz');
      expect(json['kind'], 'service');
      expect(json['category_id'], 'cat-serv');
      expect(json['start_day'], 10);
      expect(json['notify_minute'], 30);
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('paid_cycle'), isFalse);
      expect(json.containsKey('active'), isFalse);
    });
  });

  group('BillReminder.startDateFor (clamp al último día del mes)', () {
    BillReminder withStartDay(int day) => BillReminder(
      id: 'br',
      name: 'x',
      kind: ReminderKind.service,
      amount: 1,
      categoryId: 'c',
      startDay: day,
      dueDay: day,
      notifyHour: 8,
      notifyMinute: 5,
      persistent: false,
      repeatMonthly: true,
      paidCycle: null,
      active: true,
    );

    test('día que existe se respeta con hora/minuto', () {
      expect(withStartDay(10).startDateFor(2026, 3), DateTime(2026, 3, 10, 8, 5));
    });

    test('día 31 en abril (30 días) hace clamp a 30', () {
      expect(withStartDay(31).startDateFor(2026, 4), DateTime(2026, 4, 30, 8, 5));
    });

    test('día 31 en febrero no bisiesto hace clamp a 28', () {
      expect(withStartDay(31).startDateFor(2026, 2), DateTime(2026, 2, 28, 8, 5));
    });

    test('día 29 en febrero bisiesto (2028) se respeta', () {
      expect(withStartDay(29).startDateFor(2028, 2), DateTime(2028, 2, 29, 8, 5));
    });

    test('día 29 en febrero no bisiesto hace clamp a 28', () {
      expect(withStartDay(29).startDateFor(2026, 2), DateTime(2026, 2, 28, 8, 5));
    });
  });

  group('BillReminder.isPaidForCycle / cycleOf', () {
    test('cycleOf formatea YYYY-MM con cero a la izquierda', () {
      expect(cycleOf(2026, 8), '2026-08');
      expect(cycleOf(2026, 12), '2026-12');
    });

    test('isPaidForCycle compara paid_cycle con el ciclo', () {
      final paid = BillReminder.fromJson({
        'id': 'br-2',
        'name': 'x',
        'kind': 'card',
        'amount': 100,
        'category_id': 'c',
        'start_day': 5,
        'due_day': 5,
        'notify_hour': 0,
        'notify_minute': 0,
        'persistent': false,
        'repeat_monthly': true,
        'paid_cycle': '2026-08',
        'active': true,
      });
      expect(paid.isPaidForCycle('2026-08'), isTrue);
      expect(paid.isPaidForCycle('2026-09'), isFalse);
    });
  });
}

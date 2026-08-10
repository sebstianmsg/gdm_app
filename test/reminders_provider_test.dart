// Tests de la lógica pura de clasificación por ciclo (spec 16, paso 5) y del
// BillRemindersNotifier con un doble inyectado.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/reminders/reminders_provider.dart';
import 'package:gdm_app/models/bill_reminder.dart';
import 'package:gdm_app/providers/core_providers.dart';

import 'support/fake_bill_reminders_data.dart';

BillReminder reminder({
  required String id,
  int startDay = 10,
  bool repeatMonthly = true,
  String? paidCycle,
  bool active = true,
}) => BillReminder(
  id: id,
  name: id,
  kind: ReminderKind.service,
  amount: 1000,
  categoryId: 'c',
  startDay: startDay,
  dueDay: 15,
  notifyHour: 9,
  notifyMinute: 0,
  persistent: false,
  repeatMonthly: repeatMonthly,
  paidCycle: paidCycle,
  active: active,
);

void main() {
  group('currentCycle', () {
    test('formatea YYYY-MM del mes dado', () {
      expect(currentCycle(DateTime(2026, 8, 9)), '2026-08');
      expect(currentCycle(DateTime(2026, 1, 31)), '2026-01');
    });
  });

  group('classifyReminder', () {
    test('pagado este ciclo => paidThisCycle', () {
      final r = reminder(id: 'a', paidCycle: '2026-08');
      expect(classifyReminder(r, '2026-08'), ReminderStatus.paidThisCycle);
    });

    test('pagado en ciclo anterior => active (pendiente de nuevo)', () {
      final r = reminder(id: 'a', paidCycle: '2026-07');
      expect(classifyReminder(r, '2026-08'), ReminderStatus.active);
    });

    test('sin pagar y activo => active', () {
      final r = reminder(id: 'a', paidCycle: null);
      expect(classifyReminder(r, '2026-08'), ReminderStatus.active);
    });

    test('inactivo (no repite, ya pagado hace tiempo) => inactive', () {
      final r = reminder(id: 'a', repeatMonthly: false, active: false, paidCycle: '2026-07');
      expect(classifyReminder(r, '2026-08'), ReminderStatus.inactive);
    });
  });

  group('classifyAndSort', () {
    test('ordena activos primero (por día), luego pagados, luego inactivos', () {
      final list = [
        reminder(id: 'paid', paidCycle: '2026-08', startDay: 1),
        reminder(id: 'active-late', startDay: 25),
        reminder(id: 'inactive', repeatMonthly: false, active: false, paidCycle: '2026-06'),
        reminder(id: 'active-early', startDay: 3),
      ];
      final views = classifyAndSort(list, '2026-08');
      expect(views.map((v) => v.reminder.id), [
        'active-early',
        'active-late',
        'paid',
        'inactive',
      ]);
      expect(views.first.status, ReminderStatus.active);
      expect(views[2].status, ReminderStatus.paidThisCycle);
      expect(views.last.status, ReminderStatus.inactive);
    });
  });

  group('remindersToSchedule', () {
    test('solo activos y no pagados este ciclo', () {
      final list = [
        reminder(id: 'active'),
        reminder(id: 'paid', paidCycle: '2026-08'),
        reminder(id: 'inactive', repeatMonthly: false, active: false, paidCycle: '2026-06'),
        reminder(id: 'paid-prev', paidCycle: '2026-07'),
      ];
      final ids = remindersToSchedule(list, '2026-08').map((r) => r.id);
      expect(ids, containsAll(['active', 'paid-prev']));
      expect(ids, isNot(contains('paid')));
      expect(ids, isNot(contains('inactive')));
    });
  });

  group('BillRemindersNotifier', () {
    ProviderContainer containerWith(FakeBillRemindersData fake) {
      final c = ProviderContainer(overrides: [
        billRemindersDataProvider.overrideWithValue(fake),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('build carga la lista', () async {
      final fake = FakeBillRemindersData([reminder(id: 'r1')]);
      final container = containerWith(fake);
      final list = await container.read(billRemindersProvider.future);
      expect(list.map((r) => r.id), ['r1']);
    });

    test('markPaid actualiza y refresca', () async {
      final fake = FakeBillRemindersData([reminder(id: 'r1', repeatMonthly: true)]);
      final container = containerWith(fake);
      await container.read(billRemindersProvider.future);
      await container.read(billRemindersProvider.notifier).markPaid('r1', '2026-08');
      final list = container.read(billRemindersProvider).requireValue;
      expect(list.single.paidCycle, '2026-08');
    });
  });
}

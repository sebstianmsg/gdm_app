// Tests del núcleo del PAGO (spec 16, paso 11): crea el gasto, marca pagado y
// cancela; no hace nada si ya estaba pagado este ciclo (anti doble gasto).

import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/reminders/reminder_pay.dart';
import 'package:gdm_app/models/bill_reminder.dart';

BillReminder reminder({String? paidCycle}) => BillReminder(
  id: 'r1',
  name: 'Luz',
  kind: ReminderKind.service,
  amount: 1500,
  categoryId: 'cat-serv',
  startDay: 10,
  dueDay: 15,
  notifyHour: 9,
  notifyMinute: 0,
  persistent: false,
  repeatMonthly: true,
  paidCycle: paidCycle,
  active: true,
);

void main() {
  test('crea el gasto de hoy, marca pagado y cancela la notificación', () async {
    final created = <Map<String, Object?>>[];
    final marked = <({String id, String cycle})>[];
    final cancelled = <String>[];

    final ok = await performPay(
      reminder: reminder(),
      now: DateTime(2026, 8, 9, 14, 30),
      createExpense: ({required description, required amount, required date, required categoryId}) async {
        created.add({
          'description': description,
          'amount': amount,
          'date': date,
          'categoryId': categoryId,
        });
      },
      markPaid: (id, cycle) async => marked.add((id: id, cycle: cycle)),
      cancelNotification: (r) async => cancelled.add(r.id),
    );

    expect(ok, isTrue);
    expect(created.single, {
      'description': 'Luz',
      'amount': 1500.0,
      'date': DateTime(2026, 8, 9, 14, 30),
      'categoryId': 'cat-serv',
    });
    expect(marked.single, (id: 'r1', cycle: '2026-08'));
    expect(cancelled, ['r1']);
  });

  test('no hace nada si ya estaba pagado en el ciclo actual', () async {
    var sideEffects = 0;
    final ok = await performPay(
      reminder: reminder(paidCycle: '2026-08'),
      now: DateTime(2026, 8, 9),
      createExpense: ({required description, required amount, required date, required categoryId}) async {
        sideEffects++;
      },
      markPaid: (id, cycle) async => sideEffects++,
      cancelNotification: (r) async => sideEffects++,
    );

    expect(ok, isFalse);
    expect(sideEffects, 0);
  });
}

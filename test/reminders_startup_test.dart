// Test de la orquestación de re-programación (spec 16, paso 7): cancela lo que
// no corresponde y re-agenda solo los pendientes del ciclo actual.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/reminders/reminders_provider.dart';
import 'package:gdm_app/features/reminders/reminders_startup.dart';
import 'package:gdm_app/models/bill_reminder.dart';
import 'package:gdm_app/providers/core_providers.dart';

import 'support/fake_bill_reminders_data.dart';
import 'support/recording_notifications.dart';

BillReminder reminder({
  required String id,
  bool active = true,
  String? paidCycle,
  bool repeatMonthly = true,
}) => BillReminder(
  id: id,
  name: id,
  kind: ReminderKind.service,
  amount: 1000,
  categoryId: 'c',
  startDay: 10,
  dueDay: 15,
  notifyHour: 9,
  notifyMinute: 0,
  persistent: false,
  repeatMonthly: repeatMonthly,
  paidCycle: paidCycle,
  active: active,
);

void main() {
  test('syncReminderSchedules agenda pendientes y cancela el resto', () async {
    final notif = RecordingNotifications();
    final reminders = [
      reminder(id: 'active'),
      reminder(id: 'paid', paidCycle: '2026-08'),
      reminder(id: 'inactive', active: false, repeatMonthly: false, paidCycle: '2026-06'),
    ];

    await syncReminderSchedules(
      reminders: reminders,
      notifications: notif,
      now: DateTime(2026, 8, 9),
      exactAlarms: true,
    );

    // 'active' se agenda (y se cancela antes para evitar duplicado).
    expect(notif.scheduled, ['active']);
    // 'paid' e 'inactive' se cancelan; 'active' también se cancela antes de agendar.
    expect(notif.cancelled, containsAll(['paid', 'inactive', 'active']));
  });

  test('performRemindersRollAndSync reactiva y reprograma un recordatorio de ciclo anterior', () async {
    // Un repeat_monthly pagado el mes pasado (2026-07); al abrir en 2026-08
    // debe reactivarse (paid_cycle=null) y re-agendarse.
    final fake = FakeBillRemindersData([
      reminder(id: 'monthly', paidCycle: '2026-07'),
      reminder(id: 'paid-now', paidCycle: '2026-08'),
    ]);
    final container = ProviderContainer(overrides: [
      billRemindersDataProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    await container.read(billRemindersProvider.future);

    final notif = RecordingNotifications();
    await performRemindersRollAndSync(
      notifier: container.read(billRemindersProvider.notifier),
      readList: () => container.read(billRemindersProvider.future),
      notifications: notif,
      now: DateTime(2026, 8, 9),
      exactAlarms: true,
    );

    // El de ciclo anterior quedó con paid_cycle=null (reactivado) y se re-agendó.
    final list = container.read(billRemindersProvider).requireValue;
    expect(list.firstWhere((r) => r.id == 'monthly').paidCycle, isNull);
    expect(notif.scheduled, contains('monthly'));
    // El pagado de este ciclo NO se re-agenda.
    expect(notif.scheduled, isNot(contains('paid-now')));
  });
}

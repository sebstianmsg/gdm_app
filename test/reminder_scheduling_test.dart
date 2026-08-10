// Tests de reprogramWith (spec 16, paso 10): (re)programa según estado y
// devuelve avisos cuando los permisos están denegados/degradados.

import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/reminders/reminder_scheduling.dart';
import 'package:gdm_app/models/bill_reminder.dart';

import 'support/recording_notifications.dart';

BillReminder reminder({
  String id = 'r',
  bool active = true,
  String? paidCycle,
}) => BillReminder(
  id: id,
  name: 'Luz',
  kind: ReminderKind.service,
  amount: 1000,
  categoryId: 'c',
  startDay: 10,
  dueDay: 15,
  notifyHour: 9,
  notifyMinute: 0,
  persistent: false,
  repeatMonthly: true,
  paidCycle: paidCycle,
  active: active,
);

void main() {
  test('agenda un recordatorio activo no pagado y no devuelve aviso', () async {
    final notif = RecordingNotifications();
    final warning = await reprogramWith(notif, reminder());
    expect(warning, isNull);
    expect(notif.cancelled, contains('r')); // cancela antes de agendar
    expect(notif.scheduled, ['r']);
  });

  test('un recordatorio inactivo se cancela pero no se agenda', () async {
    final notif = RecordingNotifications();
    await reprogramWith(notif, reminder(active: false));
    expect(notif.cancelled, contains('r'));
    expect(notif.scheduled, isEmpty);
  });

  test('avisa si faltan permisos de notificación', () async {
    final notif = RecordingNotifications(notificationsGranted: false);
    final warning = await reprogramWith(notif, reminder());
    expect(warning, contains('notificaciones'));
  });

  test('avisa si faltan alarmas exactas', () async {
    final notif = RecordingNotifications(exactAlarmsGranted: false);
    final warning = await reprogramWith(notif, reminder());
    expect(warning, contains('exactas'));
  });
}

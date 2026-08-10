import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bill_reminder.dart';
import '../../providers/core_providers.dart';
import '../../services/reminder_notifications.dart';
import 'reminders_provider.dart';

/// Re-programa las notificaciones locales de los recordatorios al abrir la app
/// (spec 16, pasos 7 y 8). Supabase es la fuente de verdad: Android borra las
/// notificaciones al reiniciar, así que en cada arranque:
///   1. Se ejecuta el roll de ciclo (reactiva los `repeat_monthly` de meses
///      anteriores) — paso 8.
///   2. Se cancelan todas las notificaciones de los recordatorios conocidos y
///      se re-agendan solo las pendientes del ciclo actual — paso 7.
///
/// Es un [FutureProvider] que la HomeScreen observa una vez tras el login.
final remindersStartupSyncProvider = FutureProvider<void>((ref) async {
  if (!Platform.isAndroid) return;

  final notif = ref.read(reminderNotificationsProvider);
  await notif.init();
  final perms = await notif.requestPermissions();

  await performRemindersRollAndSync(
    notifier: ref.read(billRemindersProvider.notifier),
    readList: () => ref.read(billRemindersProvider.future),
    notifications: notif,
    now: DateTime.now(),
    exactAlarms: perms.exactAlarmsGranted,
  );
});

/// Ejecuta el roll de ciclo (paso 8) y luego la re-programación (paso 7).
/// Tras el roll, los `repeat_monthly` pagados en un ciclo anterior vuelven a
/// estar activos y quedan incluidos en los pendientes a re-agendar, con su
/// mismo día/monto. Separada del provider (sin el guard de plataforma) para
/// poder testear la integración roll → reprogramación.
Future<void> performRemindersRollAndSync({
  required BillRemindersNotifier notifier,
  required Future<List<BillReminder>> Function() readList,
  required ReminderNotifications notifications,
  required DateTime now,
  required bool exactAlarms,
}) async {
  final cycle = currentCycle(now);

  // Paso 8: reactiva los recordatorios de meses anteriores antes de leer la
  // lista definitiva (rollToNewCycle refresca el estado del notifier).
  await notifier.rollToNewCycle(cycle);
  final reminders = await readList();

  // Paso 7: re-agenda solo los pendientes del ciclo actual.
  await syncReminderSchedules(
    reminders: reminders,
    notifications: notifications,
    now: now,
    exactAlarms: exactAlarms,
  );
}

/// Cancela las notificaciones de todos los [reminders] y re-agenda solo las
/// pendientes del ciclo actual en el mes de [now]. Separado del provider para
/// poder testear la orquestación con un doble de [ReminderNotifications].
Future<void> syncReminderSchedules({
  required List<BillReminder> reminders,
  required ReminderNotifications notifications,
  required DateTime now,
  required bool exactAlarms,
}) async {
  final cycle = currentCycle(now);
  final pending = remindersToSchedule(reminders, cycle).toSet();

  for (final r in reminders) {
    if (!pending.contains(r)) {
      await notifications.cancel(r);
    }
  }
  for (final r in pending) {
    // Reprograma cancelando primero para evitar duplicados con el mismo id.
    await notifications.cancel(r);
    await notifications.schedule(
      r,
      year: now.year,
      month: now.month,
      exactAlarms: exactAlarms,
    );
  }
}

import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bill_reminder.dart';
import '../../providers/core_providers.dart';
import '../../services/reminder_notifications.dart';
import 'reminders_provider.dart';

/// (Re)programa la notificación de [reminder] tras crearlo/editarlo. Cancela la
/// notificación previa y agenda una nueva si el recordatorio está activo y no
/// pagado en el ciclo actual. Solicita permisos y devuelve un mensaje de aviso
/// si están denegados/degradados (o `null` si todo OK / no aplica).
///
/// No bloquea el guardado: la card 3 funciona como respaldo visual aunque las
/// notificaciones estén denegadas (spec 16, riesgos).
Future<String?> reprogramReminder(WidgetRef ref, BillReminder reminder) async {
  if (!Platform.isAndroid) return null;
  return reprogramWith(ref.read(reminderNotificationsProvider), reminder);
}

/// Núcleo testeable: recibe el servicio de notificaciones directamente (las
/// llamadas nativas ya están guardadas por plataforma dentro del servicio).
Future<String?> reprogramWith(ReminderNotifications notif, BillReminder reminder) async {
  await notif.init();
  final perms = await notif.requestPermissions();

  // Siempre cancela primero para no duplicar por id estable.
  await notif.cancel(reminder);

  final cycle = currentCycle();
  final shouldSchedule = reminder.active && !reminder.isPaidForCycle(cycle);
  if (shouldSchedule) {
    final now = DateTime.now();
    await notif.schedule(
      reminder,
      year: now.year,
      month: now.month,
      exactAlarms: perms.exactAlarmsGranted,
    );
  }

  if (!perms.notificationsGranted) {
    return 'Sin permiso de notificaciones: activalo en Ajustes para recibir el aviso.';
  }
  if (!perms.exactAlarmsGranted) {
    return 'Sin permiso de alarmas exactas: el horario del aviso puede variar.';
  }
  return null;
}

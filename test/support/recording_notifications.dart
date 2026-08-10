import 'package:gdm_app/models/bill_reminder.dart';
import 'package:gdm_app/services/reminder_notifications.dart';

/// Doble de [ReminderNotifications] que registra llamadas sin tocar el canal
/// nativo. Permisos configurables para probar los avisos de degradación.
class RecordingNotifications extends ReminderNotifications {
  RecordingNotifications({
    this.notificationsGranted = true,
    this.exactAlarmsGranted = true,
  });

  final bool notificationsGranted;
  final bool exactAlarmsGranted;

  final List<String> scheduled = [];
  final List<String> cancelled = [];
  int initCalls = 0;

  @override
  Future<void> init() async {
    initCalls++;
  }

  @override
  Future<NotificationPermissions> requestPermissions() async {
    return NotificationPermissions(
      notificationsGranted: notificationsGranted,
      exactAlarmsGranted: exactAlarmsGranted,
    );
  }

  @override
  Future<void> schedule(
    BillReminder reminder, {
    required int year,
    required int month,
    bool exactAlarms = true,
  }) async {
    scheduled.add(reminder.id);
  }

  @override
  Future<void> cancel(BillReminder reminder) async {
    cancelled.add(reminder.id);
  }
}

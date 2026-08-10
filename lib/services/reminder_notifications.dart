import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/bill_reminder.dart';

/// Resultado de solicitar permisos de notificación (spec 16, riesgos).
class NotificationPermissions {
  const NotificationPermissions({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
  });

  /// POST_NOTIFICATIONS (Android 13+). Si es `false`, nada se notifica.
  final bool notificationsGranted;

  /// SCHEDULE_EXACT_ALARM (Android 12+). Si es `false`, se degrada a alarma
  /// inexacta (el horario puede variar).
  final bool exactAlarmsGranted;
}

/// Servicio de notificaciones locales para los recordatorios de facturas.
/// Foco en Android (coherente con el README y el spec). Programa **una**
/// notificación por recordatorio en su fecha de inicio, con `ongoing` según el
/// toggle de persistencia.
class ReminderNotifications {
  ReminderNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const String _channelId = 'bill_reminders';
  static const String _channelName = 'Recordatorios de facturas';
  static const String _channelDescription =
      'Avisos de facturas/servicios/deudas a pagar';

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Inicializa el plugin y la base de zonas horarias. Idempotente.
  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
    _initialized = true;
  }

  /// Solicita los permisos necesarios (Android 13+ notificaciones, 12+ alarmas
  /// exactas). Devuelve el estado para que la UI pueda avisar si se degradan.
  Future<NotificationPermissions> requestPermissions() async {
    if (!Platform.isAndroid) {
      return const NotificationPermissions(
        notificationsGranted: false,
        exactAlarmsGranted: false,
      );
    }
    final android = _android;
    final notif = await android?.requestNotificationsPermission() ?? false;
    final exact = await android?.requestExactAlarmsPermission() ?? false;
    return NotificationPermissions(
      notificationsGranted: notif,
      exactAlarmsGranted: exact,
    );
  }

  NotificationDetails _details(BillReminder reminder) {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      // Persistente => no descartable deslizando (ongoing). Si no, autoCancel.
      ongoing: reminder.persistent,
      autoCancel: !reminder.persistent,
    );
    return NotificationDetails(android: androidDetails);
  }

  /// Programa la notificación del recordatorio en su fecha de inicio del ciclo
  /// [year]/[month] a la hora elegida. Si la fecha ya pasó en ese mes, no
  /// programa nada (el roll de ciclo se encarga del próximo mes).
  Future<void> schedule(
    BillReminder reminder, {
    required int year,
    required int month,
    bool exactAlarms = true,
  }) async {
    if (!Platform.isAndroid) return;
    await init();
    final when = reminder.startDateFor(year, month);
    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      reminder.notificationId,
      reminder.name,
      'Vence este mes — tocá PAGO al pagarla',
      scheduled,
      _details(reminder),
      androidScheduleMode: exactAlarms
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: reminder.id,
    );
  }

  /// Cancela la notificación asociada al recordatorio (por id estable).
  Future<void> cancel(BillReminder reminder) async {
    if (!Platform.isAndroid) return;
    await init();
    await _plugin.cancel(reminder.notificationId);
  }
}

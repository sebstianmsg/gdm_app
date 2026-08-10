import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bill_reminder.dart';
import '../../providers/core_providers.dart';
import '../expenses/expenses_provider.dart';
import 'reminders_provider.dart';

typedef CreateExpenseFn = Future<void> Function({
  required String description,
  required double amount,
  required DateTime date,
  required String categoryId,
});

/// Núcleo testeable del PAGO (spec 16, paso 11). Crea el gasto con la fecha de
/// [now], marca el ciclo como pagado y cancela la notificación. Devuelve
/// `false` (sin efectos) si el recordatorio ya estaba pagado en el ciclo actual
/// (evita doble gasto).
Future<bool> performPay({
  required BillReminder reminder,
  required DateTime now,
  required CreateExpenseFn createExpense,
  required Future<void> Function(String id, String cycle) markPaid,
  required Future<void> Function(BillReminder reminder) cancelNotification,
}) async {
  final cycle = currentCycle(now);
  if (reminder.isPaidForCycle(cycle)) return false;

  await createExpense(
    description: reminder.name,
    amount: reminder.amount,
    date: now,
    categoryId: reminder.categoryId,
  );
  await markPaid(reminder.id, cycle);
  await cancelNotification(reminder);
  return true;
}

/// Acción del botón PAGO: crea el gasto en el mes actual (alimenta el donut /
/// TOTAL DEL MES / movimientos personales), marca el recordatorio como pagado
/// del ciclo y cancela su notificación.
Future<void> payReminder(
  BuildContext context,
  WidgetRef ref,
  BillReminder reminder,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final now = DateTime.now();
  final monthKey = DateTime(now.year, now.month, 1);
  final expenses = ref.read(expensesProvider(monthKey).notifier);
  final reminders = ref.read(billRemindersProvider.notifier);
  final notifications = ref.read(reminderNotificationsProvider);

  final paid = await performPay(
    reminder: reminder,
    now: now,
    createExpense: expenses.create,
    markPaid: reminders.markPaid,
    cancelNotification: notifications.cancel,
  );

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        paid ? 'Pagado: ${reminder.name}' : 'Ya estaba pagado este mes',
      ),
    ),
  );
}

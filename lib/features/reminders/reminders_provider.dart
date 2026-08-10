import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bill_reminders_data.dart';
import '../../models/bill_reminder.dart';
import '../../providers/core_providers.dart';

/// Estado de un recordatorio respecto del ciclo actual (`YYYY-MM`):
/// - [active]: pendiente de pago este ciclo (muestra el botón PAGO).
/// - [paidThisCycle]: ya se pagó este ciclo (se muestra "apagado" con etiqueta).
/// - [inactive]: `active=false` (no repite y ya se pagó) — no requiere acción.
enum ReminderStatus { active, paidThisCycle, inactive }

/// Ciclo `YYYY-MM` correspondiente a una fecha (por defecto, el mes real de hoy).
String currentCycle([DateTime? now]) {
  final d = now ?? DateTime.now();
  return cycleOf(d.year, d.month);
}

/// Clasifica un recordatorio para un ciclo dado. Pura y testeable.
ReminderStatus classifyReminder(BillReminder r, String cycle) {
  if (r.isPaidForCycle(cycle)) return ReminderStatus.paidThisCycle;
  if (!r.active) return ReminderStatus.inactive;
  return ReminderStatus.active;
}

/// Recordatorios que deben tener una notificación programada para [cycle]:
/// activos y aún no pagados este ciclo. El resto debe cancelarse. Pura y
/// testeable.
List<BillReminder> remindersToSchedule(List<BillReminder> list, String cycle) =>
    list.where((r) => r.active && !r.isPaidForCycle(cycle)).toList();

/// Un recordatorio junto con su estado en el ciclo actual.
class ReminderView {
  const ReminderView(this.reminder, this.status);
  final BillReminder reminder;
  final ReminderStatus status;
}

/// Ordena/clasifica la lista para la card 3: primero los activos (pendientes)
/// por día de inicio, luego los pagados del ciclo, y al final los inactivos.
/// Ambos subgrupos se ordenan por `start_day`. Pura y testeable.
List<ReminderView> classifyAndSort(List<BillReminder> reminders, String cycle) {
  final views = reminders
      .map((r) => ReminderView(r, classifyReminder(r, cycle)))
      .toList();
  int rank(ReminderStatus s) => switch (s) {
    ReminderStatus.active => 0,
    ReminderStatus.paidThisCycle => 1,
    ReminderStatus.inactive => 2,
  };
  views.sort((a, b) {
    final byStatus = rank(a.status).compareTo(rank(b.status));
    if (byStatus != 0) return byStatus;
    return a.reminder.startDay.compareTo(b.reminder.startDay);
  });
  return views;
}

/// Fuente de verdad en memoria de los recordatorios del usuario (Supabase detrás).
class BillRemindersNotifier extends AsyncNotifier<List<BillReminder>> {
  late final BillRemindersDataSource _data;

  @override
  Future<List<BillReminder>> build() async {
    _data = ref.watch(billRemindersDataProvider);
    return _data.list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _data.list());
  }

  Future<BillReminder> create(BillReminder reminder) async {
    final created = await _data.create(reminder);
    await refresh();
    return created;
  }

  Future<BillReminder> updateReminder(BillReminder reminder) async {
    final updated = await _data.update(reminder);
    await refresh();
    return updated;
  }

  Future<void> delete(String id) async {
    await _data.delete(id);
    await refresh();
  }

  Future<BillReminder> markPaid(String id, String cycle) async {
    final updated = await _data.markPaid(id, cycle);
    await refresh();
    return updated;
  }

  Future<List<BillReminder>> rollToNewCycle(String cycle) async {
    final rolled = await _data.rollToNewCycle(cycle);
    if (rolled.isNotEmpty) await refresh();
    return rolled;
  }
}

final billRemindersProvider =
    AsyncNotifierProvider<BillRemindersNotifier, List<BillReminder>>(
  BillRemindersNotifier.new,
);

/// Derivado: la lista clasificada y ordenada para el ciclo actual (mes real).
final classifiedRemindersProvider = Provider<AsyncValue<List<ReminderView>>>((ref) {
  final cycle = currentCycle();
  return ref.watch(billRemindersProvider).whenData(
        (reminders) => classifyAndSort(reminders, cycle),
      );
});

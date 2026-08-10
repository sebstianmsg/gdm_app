import 'package:gdm_app/data/bill_reminders_data.dart';
import 'package:gdm_app/models/bill_reminder.dart';

BillReminder _withPaidCycle(BillReminder r, String? cycle, {bool? active}) =>
    BillReminder(
      id: r.id,
      name: r.name,
      kind: r.kind,
      amount: r.amount,
      categoryId: r.categoryId,
      startDay: r.startDay,
      dueDay: r.dueDay,
      notifyHour: r.notifyHour,
      notifyMinute: r.notifyMinute,
      persistent: r.persistent,
      repeatMonthly: r.repeatMonthly,
      paidCycle: cycle,
      active: active ?? r.active,
    );

/// Doble en memoria de [BillRemindersDataSource] para tests. Reproduce la
/// semántica del backend: `markPaid` setea `paid_cycle` (y desactiva si no
/// repite), `rollToNewCycle` limpia `paid_cycle` de los `repeat_monthly` con
/// ciclo anterior.
class FakeBillRemindersData implements BillRemindersDataSource {
  FakeBillRemindersData([List<BillReminder> initial = const []])
    : _items = [...initial];

  List<BillReminder> _items;
  int _seq = 0;

  final List<({String id, String cycle})> markPaidCalls = [];
  final List<String> rollCalls = [];

  @override
  Future<List<BillReminder>> list() async {
    final copy = [..._items]..sort((a, b) => a.startDay.compareTo(b.startDay));
    return copy;
  }

  @override
  Future<BillReminder> create(BillReminder reminder) async {
    final withId = _withPaidCycle(
      BillReminder(
        id: 'br-${_seq++}',
        name: reminder.name,
        kind: reminder.kind,
        amount: reminder.amount,
        categoryId: reminder.categoryId,
        startDay: reminder.startDay,
        dueDay: reminder.dueDay,
        notifyHour: reminder.notifyHour,
        notifyMinute: reminder.notifyMinute,
        persistent: reminder.persistent,
        repeatMonthly: reminder.repeatMonthly,
        paidCycle: null,
        active: true,
      ),
      null,
    );
    _items = [..._items, withId];
    return withId;
  }

  @override
  Future<BillReminder> update(BillReminder reminder) async {
    _items = _items.map((r) => r.id == reminder.id ? reminder : r).toList();
    return reminder;
  }

  @override
  Future<void> delete(String id) async {
    _items = _items.where((r) => r.id != id).toList();
  }

  @override
  Future<BillReminder> markPaid(String id, String cycle) async {
    markPaidCalls.add((id: id, cycle: cycle));
    late BillReminder updated;
    _items = _items.map((r) {
      if (r.id != id) return r;
      updated = _withPaidCycle(r, cycle, active: r.repeatMonthly ? r.active : false);
      return updated;
    }).toList();
    return updated;
  }

  @override
  Future<List<BillReminder>> rollToNewCycle(String currentCycle) async {
    rollCalls.add(currentCycle);
    final affected = <BillReminder>[];
    _items = _items.map((r) {
      final pc = r.paidCycle;
      if (r.repeatMonthly && pc != null && pc.compareTo(currentCycle) < 0) {
        final rolled = _withPaidCycle(r, null, active: true);
        affected.add(rolled);
        return rolled;
      }
      return r;
    }).toList();
    return affected;
  }
}

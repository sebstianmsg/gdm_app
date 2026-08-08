import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/shared_expenses_data.dart';
import '../../models/shared_expense.dart';
import '../../providers/core_providers.dart';

/// Clave de la familia de gastos compartidos: vínculo + mes (día 1).
typedef SharedExpensesArg = ({String partnershipId, DateTime month});

/// Gastos compartidos del vínculo y mes de `arg`. Familia por `(partnershipId,
/// month)` para no perder el caché al navegar de mes.
class SharedExpensesNotifier
    extends FamilyAsyncNotifier<List<SharedExpense>, SharedExpensesArg> {
  late final SharedExpensesDataSource _data;

  @override
  Future<List<SharedExpense>> build(SharedExpensesArg arg) async {
    _data = ref.watch(sharedExpensesDataProvider);
    return _data.listForMonth(arg.partnershipId, arg.month);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => _data.listForMonth(arg.partnershipId, arg.month),
    );
  }

  Future<void> create({
    required String description,
    required double amount,
    required DateTime date,
    required String paidBy,
  }) async {
    await _data.create(
      partnershipId: arg.partnershipId,
      description: description,
      amount: amount,
      date: date,
      paidBy: paidBy,
    );
    await refresh();
  }

  Future<void> updateExpense(
    String id, {
    String? description,
    double? amount,
    DateTime? date,
    String? paidBy,
  }) async {
    await _data.update(
      id,
      description: description,
      amount: amount,
      date: date,
      paidBy: paidBy,
    );
    await refresh();
  }

  Future<void> delete(String id) async {
    await _data.delete(id);
    await refresh();
  }
}

final sharedExpensesProvider = AsyncNotifierProvider.family<
    SharedExpensesNotifier, List<SharedExpense>, SharedExpensesArg>(
  SharedExpensesNotifier.new,
);

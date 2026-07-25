import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/expenses_api.dart';
import '../../models/expense.dart';
import '../../providers/core_providers.dart';

/// Gastos del mes `arg` (normalizado a día 1). Familia por mes para que
/// navegar prev/next no pierda el caché de meses ya visitados en la sesión.
class ExpensesNotifier extends FamilyAsyncNotifier<List<Expense>, DateTime> {
  late final ExpensesApi _api;

  @override
  Future<List<Expense>> build(DateTime arg) async {
    _api = ref.watch(expensesApiProvider);
    return _api.listForMonth(arg);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _api.listForMonth(arg));
  }

  Future<void> create({
    required String description,
    required double amount,
    required DateTime date,
    required String categoryId,
  }) async {
    await _api.create(
      description: description,
      amount: amount,
      date: date,
      categoryId: categoryId,
    );
    await refresh();
  }

  Future<void> updateExpense(
    String id, {
    String? description,
    double? amount,
    DateTime? date,
    String? categoryId,
  }) async {
    await _api.update(
      id,
      description: description,
      amount: amount,
      date: date,
      categoryId: categoryId,
    );
    await refresh();
  }

  Future<void> delete(String id) async {
    await _api.delete(id);
    await refresh();
  }
}

final expensesProvider =
    AsyncNotifierProvider.family<ExpensesNotifier, List<Expense>, DateTime>(
  ExpensesNotifier.new,
);

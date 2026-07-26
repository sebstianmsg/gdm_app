import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart';

/// Contrato de la capa de datos de gastos. Permite inyectar dobles en los
/// tests de providers sin depender del SDK real.
abstract interface class ExpensesDataSource {
  Future<List<Expense>> listForMonth(DateTime month);
  Future<Expense> create({
    required String description,
    required double amount,
    required DateTime date,
    required String categoryId,
  });
  Future<Expense> update(
    String id, {
    String? description,
    double? amount,
    DateTime? date,
    String? categoryId,
  });
  Future<void> delete(String id);
}

/// Acceso a gastos vía el SDK de Supabase. RLS (`auth.uid() = user_id`) aísla
/// por usuario; seteamos `user_id` en los inserts para el `with check`.
class ExpensesData implements ExpensesDataSource {
  ExpensesData(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  /// Gastos del mes de `month`, filtrando por rango `[primer día, primer día
  /// del mes siguiente)` sobre la columna `date`.
  @override
  Future<List<Expense>> listForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await _client
        .from('expenses')
        .select()
        .gte('date', formatDateApi(start))
        .lt('date', formatDateApi(end))
        .order('date', ascending: false);
    return rows.map((e) => Expense.fromJson(e)).toList();
  }

  @override
  Future<Expense> create({
    required String description,
    required double amount,
    required DateTime date,
    required String categoryId,
  }) async {
    final row = await _client
        .from('expenses')
        .insert({
          'description': description,
          'amount': amount,
          'date': formatDateApi(date),
          'category_id': categoryId,
          'user_id': _userId,
        })
        .select()
        .single();
    return Expense.fromJson(row);
  }

  /// Actualización parcial: solo se mandan los campos presentes.
  @override
  Future<Expense> update(
    String id, {
    String? description,
    double? amount,
    DateTime? date,
    String? categoryId,
  }) async {
    final row = await _client
        .from('expenses')
        .update({
          if (description != null) 'description': description,
          if (amount != null) 'amount': amount,
          if (date != null) 'date': formatDateApi(date),
          if (categoryId != null) 'category_id': categoryId,
        })
        .eq('id', id)
        .select()
        .single();
    return Expense.fromJson(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }
}

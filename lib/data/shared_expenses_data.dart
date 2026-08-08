import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart' show formatDateApi;
import '../models/shared_expense.dart';

/// Contrato de la capa de datos de gastos compartidos (spec 14). Permite
/// inyectar dobles en los tests sin depender del SDK real.
abstract interface class SharedExpensesDataSource {
  /// Gastos compartidos del vínculo [partnershipId] en el mes de [month].
  Future<List<SharedExpense>> listForMonth(String partnershipId, DateTime month);

  Future<SharedExpense> create({
    required String partnershipId,
    required String description,
    required double amount,
    required DateTime date,
    required String paidBy,
  });

  Future<SharedExpense> update(
    String id, {
    String? description,
    double? amount,
    DateTime? date,
    String? paidBy,
  });

  Future<void> delete(String id);
}

/// Acceso a gastos compartidos vía el SDK de Supabase. RLS (`is_partner_member`)
/// aísla por vínculo; seteamos `created_by` en el insert para el `with check`.
class SharedExpensesData implements SharedExpensesDataSource {
  SharedExpensesData(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<SharedExpense>> listForMonth(
    String partnershipId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await _client
        .from('shared_expenses')
        .select()
        .eq('partnership_id', partnershipId)
        .gte('date', formatDateApi(start))
        .lt('date', formatDateApi(end))
        .order('date', ascending: false);
    return rows.map((e) => SharedExpense.fromJson(e)).toList();
  }

  @override
  Future<SharedExpense> create({
    required String partnershipId,
    required String description,
    required double amount,
    required DateTime date,
    required String paidBy,
  }) async {
    final row = await _client
        .from('shared_expenses')
        .insert({
          'partnership_id': partnershipId,
          'description': description,
          'amount': amount,
          'date': formatDateApi(date),
          'paid_by': paidBy,
          'created_by': _userId,
        })
        .select()
        .single();
    return SharedExpense.fromJson(row);
  }

  @override
  Future<SharedExpense> update(
    String id, {
    String? description,
    double? amount,
    DateTime? date,
    String? paidBy,
  }) async {
    final row = await _client
        .from('shared_expenses')
        .update({
          if (description != null) 'description': description,
          if (amount != null) 'amount': amount,
          if (date != null) 'date': formatDateApi(date),
          if (paidBy != null) 'paid_by': paidBy,
        })
        .eq('id', id)
        .select()
        .single();
    return SharedExpense.fromJson(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('shared_expenses').delete().eq('id', id);
  }
}

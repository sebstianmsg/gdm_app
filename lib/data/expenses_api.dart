import '../models/expense.dart';
import 'api_client.dart';

class ExpensesApi {
  ExpensesApi(this._client);

  final ApiClient _client;

  /// GET /api/expenses?month=YYYY-MM (param obligatorio).
  Future<List<Expense>> listForMonth(DateTime month) async {
    final monthParam =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final data = await _client.get(
      '/api/expenses',
      query: {'month': monthParam},
    ) as List;
    return data
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Expense> create({
    required String description,
    required double amount,
    required DateTime date,
    required String categoryId,
  }) async {
    final data = await _client.post(
      '/api/expenses',
      body: {
        'description': description,
        'amount': amount,
        'date': formatDateApi(date),
        'categoryId': categoryId,
      },
    );
    return Expense.fromJson(data as Map<String, dynamic>);
  }

  /// Actualización parcial: solo se mandan los campos presentes.
  Future<Expense> update(
    String id, {
    String? description,
    double? amount,
    DateTime? date,
    String? categoryId,
  }) async {
    final body = <String, dynamic>{
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': formatDateApi(date),
      if (categoryId != null) 'categoryId': categoryId,
    };
    final data = await _client.put('/api/expenses/$id', body: body);
    return Expense.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(String id) =>
      _client.delete('/api/expenses/$id', body: {'confirmed': true});
}

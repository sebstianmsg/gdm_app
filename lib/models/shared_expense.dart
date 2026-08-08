import 'expense.dart' show formatDateApi, parseAmount, parseDateApi;

/// Gasto compartido entre los dos miembros de un [Partnership] (spec 14).
/// No tiene categoría (el MVP no categoriza compartidos) y vive separado de
/// los gastos personales (`expenses`).
class SharedExpense {
  const SharedExpense({
    required this.id,
    required this.partnershipId,
    required this.description,
    required this.amount,
    required this.date,
    required this.paidBy,
    required this.createdBy,
  });

  final String id, partnershipId, description, paidBy, createdBy;
  final double amount;
  final DateTime date;

  /// Mapeo desde una fila de Postgres (snake_case).
  factory SharedExpense.fromJson(Map<String, dynamic> json) => SharedExpense(
    id: json['id'] as String,
    partnershipId: json['partnership_id'] as String,
    description: json['description'] as String,
    amount: parseAmount(json['amount']),
    date: parseDateApi(json['date'] as String),
    paidBy: json['paid_by'] as String,
    createdBy: json['created_by'] as String,
  );

  Map<String, dynamic> toCreateJson() => {
    'partnership_id': partnershipId,
    'description': description,
    'amount': amount,
    'date': formatDateApi(date),
    'paid_by': paidBy,
    'created_by': createdBy,
  };

  Map<String, dynamic> toUpdateJson() => {
    'description': description,
    'amount': amount,
    'date': formatDateApi(date),
    'paid_by': paidBy,
  };
}

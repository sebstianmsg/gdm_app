/// Formatea una fecha como `YYYY-MM-DD`, el formato que espera/devuelve la
/// API (columna `date` de Postgres, sin hora/timezone).
String formatDateApi(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseDateApi(String date) {
  final parts = date.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.categoryId,
  });

  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String categoryId;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    description: json['description'] as String,
    amount: (json['amount'] as num).toDouble(),
    date: parseDateApi(json['date'] as String),
    categoryId: json['categoryId'] as String,
  );

  Map<String, dynamic> toCreateJson() => {
    'description': description,
    'amount': amount,
    'date': formatDateApi(date),
    'categoryId': categoryId,
  };
}

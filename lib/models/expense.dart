/// Formatea una fecha como `YYYY-MM-DD`, el formato que espera/devuelve la
/// API (columna `date` de Postgres, sin hora/timezone).
String formatDateApi(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Formatea una fecha como `día/mes/año` (ej. `26/07/2026`), día y mes con
/// cero a la izquierda. Solo para mostrar en la UI: la persistencia y las
/// queries siguen usando [formatDateApi] (`YYYY-MM-DD`).
String formatDateEs(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString().padLeft(4, '0');
  return '$d/$m/$y';
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

  /// Mapeo desde una fila de Postgres (snake_case): `category_id`.
  ///
  /// `amount` viene de `numeric`, que el SDK puede devolver como `num` o como
  /// `String` — se parsea de forma defensiva a `double`.
  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    description: json['description'] as String,
    amount: parseAmount(json['amount']),
    date: parseDateApi(json['date'] as String),
    categoryId: json['category_id'] as String,
  );

  Map<String, dynamic> toCreateJson() => {
    'description': description,
    'amount': amount,
    'date': formatDateApi(date),
    'category_id': categoryId,
  };
}

/// Parseo defensivo de `numeric` de Postgres a `double`. Acepta `num` o
/// `String` (según cómo el SDK deserialice la columna) y falla claro si no.
double parseAmount(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final parsed = double.tryParse(raw);
    if (parsed != null) return parsed;
  }
  throw FormatException('amount inválido: $raw');
}

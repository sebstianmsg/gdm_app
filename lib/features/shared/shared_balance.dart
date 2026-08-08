import '../../models/shared_expense.dart';

/// Resultado puro del balance compartido de un mes (spec 14). Meramente
/// **informativo**: sin deudas, sin "saldar", sin acumulado histórico.
class SharedBalance {
  const SharedBalance({
    required this.total,
    required this.paidByMe,
    required this.paidByPartner,
    required this.partnerName,
  });

  /// TOTAL COMPARTIDO del mes (suma de todos los gastos).
  final double total;

  /// Cuánto puso "yo" y cuánto la otra persona.
  final double paidByMe, paidByPartner;
  final String partnerName;

  /// Diferencia de aportes (siempre ≥ 0). Es lo que muestra el copy
  /// "Diferencia $Z"; no implica una deuda a saldar.
  double get difference => (paidByMe - paidByPartner).abs();
}

/// Función pura: resume los [expenses] de un mes respecto de [me].
/// No depende de red ni de Riverpod, para poder testearla directo.
SharedBalance summarize(
  List<SharedExpense> expenses, {
  required String me,
  required String partnerName,
}) {
  var total = 0.0;
  var paidByMe = 0.0;
  var paidByPartner = 0.0;
  for (final e in expenses) {
    total += e.amount;
    if (e.paidBy == me) {
      paidByMe += e.amount;
    } else {
      paidByPartner += e.amount;
    }
  }
  return SharedBalance(
    total: total,
    paidByMe: paidByMe,
    paidByPartner: paidByPartner,
    partnerName: partnerName,
  );
}

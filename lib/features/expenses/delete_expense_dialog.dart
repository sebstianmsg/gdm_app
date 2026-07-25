import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';

/// "¿Confirmás borrar el gasto '{desc}' de {monto}?" — réplica de
/// `#confirmDeleteExpenseOverlay`. Devuelve `true` si el usuario confirma.
Future<bool> showDeleteExpenseDialog(BuildContext context, Expense expense) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Borrar gasto'),
      content: Text(
        "¿Confirmás borrar el gasto '${expense.description}' de "
        '${formatMoney(expense.amount)}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.alert,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

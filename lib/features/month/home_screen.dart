import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../auth/auth_provider.dart';
import '../categories/categories_modal.dart';
import '../categories/categories_provider.dart';
import '../expenses/delete_expense_dialog.dart';
import '../expenses/expense_form.dart';
import '../expenses/expenses_provider.dart';
import 'category_summary.dart';
import 'donut_card.dart';
import 'month_provider.dart';
import 'movements_card.dart';

/// Pantalla principal. Réplica de `.wrap` en `public/index.html`: header,
/// selector de mes + total, donut por categoría, movimientos.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final expensesAsync = ref.watch(expensesProvider(month));
    final categories = categoriesAsync.valueOrNull ?? const [];
    final expenses = expensesAsync.valueOrNull ?? const [];
    final total = expenses.fold<double>(0, (a, e) => a + e.amount);
    final summaries = summarizeByCategory(expenses, categories);
    final isLoading = expensesAsync.isLoading && !expensesAsync.hasValue;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(categoriesProvider.notifier).refresh();
            await ref.read(expensesProvider(month).notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Header(
                onLogout: () async {
                  final confirmed = await _confirmLogout(context);
                  if (confirmed) {
                    ref.read(authProvider.notifier).logout();
                  }
                },
              ),
              const SizedBox(height: 20),
              _MonthCard(month: month, total: total),
              const SizedBox(height: 16),
              DonutCard(
                summaries: summaries,
                onManageCategories: () => showCategoriesModal(context),
                onAddPressed: () => showAddExpenseSheet(
                  context,
                  categories: categories,
                  onSubmit: (description, amount, date, categoryId) {
                    ref
                        .read(expensesProvider(month).notifier)
                        .create(
                          description: description,
                          amount: amount,
                          date: date,
                          categoryId: categoryId,
                        );
                  },
                ),
              ),
              const SizedBox(height: 16),
              MovementsCard(
                expenses: expenses,
                categories: categories,
                isLoading: isLoading,
                onSave: (id, description, amount, date, categoryId) {
                  ref
                      .read(expensesProvider(month).notifier)
                      .updateExpense(
                        id,
                        description: description,
                        amount: amount,
                        date: date,
                        categoryId: categoryId,
                      );
                },
                onDelete: (expense) async {
                  final confirmed = await showDeleteExpenseDialog(context, expense);
                  if (confirmed) {
                    ref.read(expensesProvider(month).notifier).delete(expense.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muestra un diálogo de confirmación antes de cerrar sesión.
/// Devuelve `true` solo si el usuario confirma; `false` al cancelar o descartar.
Future<bool> _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Cerrar sesión?'),
      content: const Text('Tu sesión se cerrará y volverás al login.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _Header extends StatelessWidget {
  const _Header({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LIBRO DE GASTOS', style: AppTextStyles.eyebrow),
              const SizedBox(height: 4),
              Text('Mis gastos', style: AppTextStyles.h1),
            ],
          ),
        ),
        // Botón de salir flotando arriba a la derecha, alineado con el eyebrow.
        IconButton(
          icon: const Icon(Icons.power_settings_new, color: AppColors.textMuted),
          onPressed: onLogout,
          tooltip: 'Cerrar sesión',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _MonthCard extends ConsumerWidget {
  const _MonthCard({required this.month, required this.total});

  final DateTime month;
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _MonthPickerButton(
            icon: Icons.chevron_left,
            onTap: () => ref.read(selectedMonthProvider.notifier).previous(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatMonthLabel(month),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          _MonthPickerButton(
            icon: Icons.chevron_right,
            onTap: () => ref.read(selectedMonthProvider.notifier).next(),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('TOTAL DEL MES', style: AppTextStyles.sectionLabel),
              Text(formatMoney(total), style: AppTextStyles.total),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthPickerButton extends StatelessWidget {
  const _MonthPickerButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 20)),
      ),
    );
  }
}

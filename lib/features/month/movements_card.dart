import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/expense.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../expenses/expense_row.dart';
import 'movements_grouping.dart';

/// Tarjeta colapsable "Movimientos". Réplica de `.movs-card` en
/// `public/index.html`: arranca cerrada, ordenable por categoría (default) o
/// por fecha, estado vacío/cargando.
class MovementsCard extends StatefulWidget {
  const MovementsCard({
    super.key,
    required this.expenses,
    required this.categories,
    required this.isLoading,
    required this.onSave,
    required this.onDelete,
  });

  final List<Expense> expenses;
  final List<Category> categories;
  final bool isLoading;
  final void Function(String id, String description, double amount, DateTime date, String categoryId)
  onSave;
  final void Function(Expense expense) onDelete;

  @override
  State<MovementsCard> createState() => _MovementsCardState();
}

class _MovementsCardState extends State<MovementsCard> {
  bool _expanded = false;
  MovementsSort _sort = MovementsSort.category;
  String? _editingId;

  Category? _categoryFor(String id) {
    for (final c in widget.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Text('MOVIMIENTOS', style: AppTextStyles.sectionLabel),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) _buildBody(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Cargando...', style: TextStyle(color: AppColors.textMuted))),
      );
    }
    if (widget.expenses.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Text(
              'Nada cargado todavía',
              style: TextStyle(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
                fontSize: 20,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'agregá un gasto desde el + para empezar el mes',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('Ordenar por', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const Spacer(),
            DropdownButton<MovementsSort>(
              value: _sort,
              dropdownColor: AppColors.card,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: MovementsSort.category, child: Text('Por categoría')),
                DropdownMenuItem(value: MovementsSort.date, child: Text('Por fecha')),
              ],
              onChanged: (v) => setState(() => _sort = v ?? MovementsSort.category),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_sort == MovementsSort.category) _buildByCategory() else _buildByDate(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildByCategory() {
    final groups = groupByCategory(widget.expenses, widget.categories);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groups.map((g) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    if (g.category != null)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse('FF${g.category!.color.replaceFirst('#', '')}', radix: 16),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      g.category?.name ?? 'Otros',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(formatMoney(g.total), style: AppTextStyles.amount),
                  ],
                ),
              ),
              ...g.items.map(_rowFor),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildByDate() {
    final groups = groupByDate(widget.expenses);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groups.map((g) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  capitalize(formatDayHeader(g.date)),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              ...g.items.map(_rowFor),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _rowFor(Expense e) {
    return ExpenseRow(
      key: ValueKey(e.id),
      expense: e,
      category: _categoryFor(e.categoryId),
      categories: widget.categories,
      isEditing: _editingId == e.id,
      onStartEdit: () => setState(() => _editingId = e.id),
      onCancelEdit: () => setState(() => _editingId = null),
      onSave: (desc, amount, date, categoryId) {
        widget.onSave(e.id, desc, amount, date, categoryId);
        setState(() => _editingId = null);
      },
      onDelete: () => widget.onDelete(e),
    );
  }
}

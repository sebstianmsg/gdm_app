import '../../models/category.dart';
import '../../models/expense.dart';

class CategorySummary {
  const CategorySummary({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  final Category category;
  final double amount;
  final double percentage; // 0..100
}

/// Agrupa gastos por categoría y ordena de mayor a menor monto, igual que
/// `catSummary`/leyenda/donut en `public/js/app.js`.
List<CategorySummary> summarizeByCategory(
  List<Expense> expenses,
  List<Category> categories,
) {
  final byCategory = <String, double>{};
  for (final e in expenses) {
    byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
  }
  final total = byCategory.values.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return const [];

  final fallback = Category(
    id: '',
    name: 'Otros',
    color: '#8B968F',
    icon: 'help',
    isDeletable: false,
  );

  final entries = byCategory.entries.map((entry) {
    final category = categories.firstWhere(
      (c) => c.id == entry.key,
      orElse: () => fallback,
    );
    return CategorySummary(
      category: category,
      amount: entry.value,
      percentage: entry.value / total * 100,
    );
  }).toList();

  entries.sort((a, b) => b.amount.compareTo(a.amount));
  return entries;
}

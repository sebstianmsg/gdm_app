import '../../models/category.dart';
import '../../models/expense.dart';

enum MovementsSort { category, date }

class CategoryGroup {
  const CategoryGroup({
    required this.category,
    required this.total,
    required this.items,
  });

  final Category? category;
  final double total;
  final List<Expense> items;
}

class DateGroup {
  const DateGroup({required this.date, required this.items});

  final DateTime date;
  final List<Expense> items;
}

/// Grupos por categoría, ordenados por monto total desc; dentro, por fecha
/// desc. Réplica de `renderListByCategory` en `public/js/app.js`.
List<CategoryGroup> groupByCategory(
  List<Expense> expenses,
  List<Category> categories,
) {
  final byCategory = <String, List<Expense>>{};
  for (final e in expenses) {
    (byCategory[e.categoryId] ??= []).add(e);
  }
  final groups = byCategory.entries.map((entry) {
    Category? category;
    for (final c in categories) {
      if (c.id == entry.key) {
        category = c;
        break;
      }
    }
    final items = List<Expense>.from(entry.value)
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = items.fold<double>(0, (a, e) => a + e.amount);
    return CategoryGroup(category: category, total: total, items: items);
  }).toList();
  groups.sort((a, b) => b.total.compareTo(a.total));
  return groups;
}

/// Grupos por día, más reciente primero. Réplica de `renderListByDate`.
List<DateGroup> groupByDate(List<Expense> expenses) {
  final byDay = <DateTime, List<Expense>>{};
  for (final e in expenses) {
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    (byDay[day] ??= []).add(e);
  }
  final groups = byDay.entries
      .map((entry) => DateGroup(date: entry.key, items: entry.value))
      .toList();
  groups.sort((a, b) => b.date.compareTo(a.date));
  return groups;
}

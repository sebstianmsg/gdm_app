// Tests de los providers de datos usando dobles de la capa de datos inyectados
// vía override de `categoriesDataProvider` / `expensesDataProvider`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/data/categories_data.dart';
import 'package:gdm_app/data/expenses_data.dart';
import 'package:gdm_app/features/categories/categories_provider.dart';
import 'package:gdm_app/features/expenses/expenses_provider.dart';
import 'package:gdm_app/models/category.dart';
import 'package:gdm_app/models/expense.dart';
import 'package:gdm_app/providers/core_providers.dart';

Category _cat(String id, String name, {bool deletable = true}) =>
    Category(id: id, name: name, color: '#FFFFFF', icon: 'help', isDeletable: deletable);

class _FakeCategoriesData implements CategoriesDataSource {
  _FakeCategoriesData(this._items);

  List<Category> _items;
  final List<({String id, String otrosId})> deleteCalls = [];

  @override
  Future<List<Category>> list() async => _items;

  @override
  Future<Category> create({
    required String name,
    required String color,
    required String icon,
  }) async {
    final c = _cat('new-$name', name);
    _items = [..._items, c];
    return c;
  }

  @override
  Future<Category> update(String id, {String? name, String? color, String? icon}) async =>
      _cat(id, name ?? 'x');

  @override
  Future<void> delete(String id, {required String otrosId}) async {
    deleteCalls.add((id: id, otrosId: otrosId));
    _items = _items.where((c) => c.id != id).toList();
  }
}

class _FakeExpensesData implements ExpensesDataSource {
  _FakeExpensesData(this._byMonth);

  final Map<String, List<Expense>> _byMonth;
  final List<DateTime> listCalls = [];

  String _key(DateTime m) => '${m.year}-${m.month}';

  @override
  Future<List<Expense>> listForMonth(DateTime month) async {
    listCalls.add(month);
    return _byMonth[_key(month)] ?? const [];
  }

  @override
  Future<Expense> create({
    required String description,
    required double amount,
    required DateTime date,
    required String categoryId,
  }) async =>
      Expense(
        id: 'e',
        description: description,
        amount: amount,
        date: date,
        categoryId: categoryId,
      );

  @override
  Future<Expense> update(
    String id, {
    String? description,
    double? amount,
    DateTime? date,
    String? categoryId,
  }) async =>
      Expense(
        id: id,
        description: description ?? 'x',
        amount: amount ?? 0,
        date: date ?? DateTime(2026, 1, 1),
        categoryId: categoryId ?? 'c',
      );

  @override
  Future<void> delete(String id) async {}
}

ProviderContainer _containerWith(List<Override> overrides) {
  final c = ProviderContainer(overrides: overrides);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('CategoriesNotifier', () {
    test('build carga la lista desde la capa de datos', () async {
      final fake = _FakeCategoriesData([_cat('1', 'Comida')]);
      final container = _containerWith([
        categoriesDataProvider.overrideWithValue(fake),
      ]);

      final list = await container.read(categoriesProvider.future);
      expect(list.map((c) => c.name), ['Comida']);
    });

    test('delete usa "Otros" (no borrable) como destino de la RPC', () async {
      final fake = _FakeCategoriesData([
        _cat('1', 'Comida'),
        _cat('otros', 'Otros', deletable: false),
      ]);
      final container = _containerWith([
        categoriesDataProvider.overrideWithValue(fake),
      ]);

      await container.read(categoriesProvider.future);
      await container.read(categoriesProvider.notifier).delete('1');

      expect(fake.deleteCalls, hasLength(1));
      expect(fake.deleteCalls.single.id, '1');
      expect(fake.deleteCalls.single.otrosId, 'otros');
    });

    test('delete falla si se intenta borrar "Otros"', () async {
      final fake = _FakeCategoriesData([
        _cat('otros', 'Otros', deletable: false),
      ]);
      final container = _containerWith([
        categoriesDataProvider.overrideWithValue(fake),
      ]);

      await container.read(categoriesProvider.future);
      expect(
        () => container.read(categoriesProvider.notifier).delete('otros'),
        throwsStateError,
      );
    });
  });

  group('ExpensesNotifier', () {
    test('build carga los gastos del mes pedido', () async {
      final fake = _FakeExpensesData({
        '2026-7': [
          Expense(
            id: 'e1',
            description: 'Café',
            amount: 1500,
            date: DateTime(2026, 7, 10),
            categoryId: 'c1',
          ),
        ],
      });
      final container = _containerWith([
        expensesDataProvider.overrideWithValue(fake),
      ]);

      final month = DateTime(2026, 7, 1);
      final list = await container.read(expensesProvider(month).future);

      expect(list, hasLength(1));
      expect(list.single.description, 'Café');
      expect(fake.listCalls, [month]);
    });
  });
}

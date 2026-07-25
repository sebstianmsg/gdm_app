import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/categories_api.dart';
import '../../models/category.dart';
import '../../providers/core_providers.dart';

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  late final CategoriesApi _api;

  @override
  Future<List<Category>> build() async {
    _api = ref.watch(categoriesApiProvider);
    return _api.list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _api.list());
  }

  Future<void> create({required String name, required String color}) async {
    await _api.create(name: name, color: color);
    await refresh();
  }

  Future<void> updateCategory(String id, {String? name, String? color}) async {
    await _api.update(id, name: name, color: color);
    await refresh();
  }

  /// Borra y reasigna gastos a "Otros". El caller debe invalidar/recargar
  /// los gastos del mes visible después de esto.
  Future<void> delete(String id) async {
    await _api.delete(id);
    await refresh();
  }

  /// Busca por id en el estado actual (útil para pintar chips/donut).
  Category? byId(String id) {
    final list = state.valueOrNull;
    if (list == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }
}

final categoriesProvider = AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
  CategoriesNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/categories_data.dart';
import '../../models/category.dart';
import '../../providers/core_providers.dart';

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  late final CategoriesDataSource _data;

  @override
  Future<List<Category>> build() async {
    _data = ref.watch(categoriesDataProvider);
    return _data.list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _data.list());
  }

  Future<void> create({
    required String name,
    required String color,
    required String icon,
  }) async {
    await _data.create(name: name, color: color, icon: icon);
    await refresh();
  }

  Future<void> updateCategory(String id, {String? name, String? color, String? icon}) async {
    await _data.update(id, name: name, color: color, icon: icon);
    await refresh();
  }

  /// Borra y reasigna gastos a "Otros" vía RPC. El caller debe invalidar/recargar
  /// los gastos del mes visible después de esto.
  Future<void> delete(String id) async {
    final otros = _otrosCategory();
    if (otros == null) {
      throw StateError('No existe la categoría "Otros" para reasignar gastos.');
    }
    if (id == otros.id) {
      throw StateError('La categoría "Otros" no se puede borrar.');
    }
    await _data.delete(id, otrosId: otros.id);
    await refresh();
  }

  /// La categoría destino del borrado: la no-borrable ("Otros").
  Category? _otrosCategory() {
    final list = state.valueOrNull;
    if (list == null) return null;
    for (final c in list) {
      if (!c.isDeletable) return c;
    }
    return null;
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

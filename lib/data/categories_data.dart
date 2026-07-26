import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';

/// Contrato de la capa de datos de categorías. Permite inyectar dobles en los
/// tests de providers sin depender del SDK real.
abstract interface class CategoriesDataSource {
  Future<List<Category>> list();
  Future<Category> create({required String name, required String color});
  Future<Category> update(String id, {String? name, String? color});
  Future<void> delete(String id, {required String otrosId});
}

/// Acceso a categorías vía el SDK de Supabase. El aislamiento por usuario lo
/// garantiza RLS (`auth.uid() = user_id`); igual seteamos `user_id` en los
/// inserts para cumplir el `with check` de la policy.
class CategoriesData implements CategoriesDataSource {
  CategoriesData(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Category>> list() async {
    final rows = await _client
        .from('categories')
        .select()
        .order('name');
    return rows
        .map((e) => Category.fromJson(e))
        .toList();
  }

  @override
  Future<Category> create({required String name, required String color}) async {
    final row = await _client
        .from('categories')
        .insert({'name': name, 'color': color, 'user_id': _userId})
        .select()
        .single();
    return Category.fromJson(row);
  }

  /// Actualización parcial: solo se mandan los campos presentes.
  @override
  Future<Category> update(String id, {String? name, String? color}) async {
    final row = await _client
        .from('categories')
        .update({
          if (name != null) 'name': name,
          if (color != null) 'color': color,
        })
        .eq('id', id)
        .select()
        .single();
    return Category.fromJson(row);
  }

  /// Reasigna los gastos de la categoría a "Otros" y la borra, vía la RPC
  /// `delete_category(p_category_id, p_otros_id)`.
  @override
  Future<void> delete(String id, {required String otrosId}) async {
    await _client.rpc('delete_category', params: {
      'p_category_id': id,
      'p_otros_id': otrosId,
    });
  }
}

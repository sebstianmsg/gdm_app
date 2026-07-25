import '../models/category.dart';
import 'api_client.dart';

class CategoriesApi {
  CategoriesApi(this._client);

  final ApiClient _client;

  Future<List<Category>> list() async {
    final data = await _client.get('/api/categories') as List;
    return data
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Category> create({required String name, required String color}) async {
    final data = await _client.post(
      '/api/categories',
      body: {'name': name, 'color': color},
    );
    return Category.fromJson(data as Map<String, dynamic>);
  }

  /// Actualización parcial: solo se mandan los campos presentes.
  Future<Category> update(String id, {String? name, String? color}) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (color != null) 'color': color,
    };
    final data = await _client.put('/api/categories/$id', body: body);
    return Category.fromJson(data as Map<String, dynamic>);
  }

  /// Reasigna los gastos de la categoría a "Otros" y la borra. 204 sin body.
  Future<void> delete(String id) =>
      _client.delete('/api/categories/$id', body: {'confirmed': true});
}

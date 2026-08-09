class Category {
  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.isDeletable,
  });

  final String id;
  final String name;

  /// Hex `#RRGGBB` (viene de la DB y es editable por el usuario). El color a
  /// **mostrar** en la UI pasa siempre por `displayCategoryColor` (en
  /// `category_icons.dart`), que introduce la única excepción: la categoría
  /// intocable "Otros" (`!isDeletable`) se pinta en un gris fijo solo visual.
  final String color;

  /// Clave del catálogo de íconos (ej. `'cart'`). Fallback `'help'` ante
  /// filas sin `icon` o con una clave desconocida.
  final String icon;
  final bool isDeletable;

  /// Mapeo desde una fila de Postgres (snake_case): `is_deletable`.
  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String,
    icon: (json['icon'] as String?) ?? 'help',
    isDeletable: json['is_deletable'] as bool,
  );

  Category copyWith({String? name, String? color, String? icon}) => Category(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    isDeletable: isDeletable,
  );
}

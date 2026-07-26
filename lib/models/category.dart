class Category {
  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.isDeletable,
  });

  final String id;
  final String name;

  /// Hex `#RRGGBB`. Siempre se pinta con este valor (viene de la DB y es
  /// editable por el usuario) — nunca con constantes locales.
  final String color;
  final bool isDeletable;

  /// Mapeo desde una fila de Postgres (snake_case): `is_deletable`.
  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String,
    isDeletable: json['is_deletable'] as bool,
  );

  Category copyWith({String? name, String? color}) => Category(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    isDeletable: isDeletable,
  );
}

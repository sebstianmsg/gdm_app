/// Vínculo 1-a-1 entre dos usuarios (spec 14). El orden low/high está
/// normalizado en la DB (`user_low < user_high`); acá no importa ese orden,
/// se resuelve todo respecto de "yo" con [partnerName].
class Partnership {
  const Partnership({
    required this.id,
    required this.userLow,
    required this.userHigh,
    required this.userLowName,
    required this.userHighName,
    required this.unlinkedAt,
  });

  final String id;
  final String userLow, userHigh, userLowName, userHighName;

  /// `null` = vínculo activo; no-nulo = archivado (soft-unlink).
  final DateTime? unlinkedAt;

  bool get isActive => unlinkedAt == null;

  /// Nombre de la otra persona respecto de [me].
  String partnerName(String me) => me == userLow ? userHighName : userLowName;

  /// `user_id` de la otra persona respecto de [me].
  String partnerId(String me) => me == userLow ? userHigh : userLow;

  /// Mapeo desde una fila de Postgres (snake_case).
  factory Partnership.fromJson(Map<String, dynamic> json) => Partnership(
    id: json['id'] as String,
    userLow: json['user_low'] as String,
    userHigh: json['user_high'] as String,
    userLowName: json['user_low_name'] as String,
    userHighName: json['user_high_name'] as String,
    unlinkedAt: json['unlinked_at'] == null
        ? null
        : DateTime.parse(json['unlinked_at'] as String),
  );
}

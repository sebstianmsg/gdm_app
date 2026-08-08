/// Código efímero de invitación para vincularse (spec 14). Lo devuelve la RPC
/// `create_partner_invite`; el cliente solo muestra el [code].
class PartnerInvite {
  const PartnerInvite({
    required this.id,
    required this.code,
    required this.inviterId,
    required this.inviterName,
    required this.expiresAt,
    required this.consumedAt,
  });

  final String id;
  final String code;
  final String inviterId;
  final String inviterName;
  final DateTime expiresAt;

  /// `null` = pendiente; no-nulo = ya consumido.
  final DateTime? consumedAt;

  bool get isPending => consumedAt == null && expiresAt.isAfter(DateTime.now());

  /// Mapeo desde una fila de Postgres (snake_case).
  factory PartnerInvite.fromJson(Map<String, dynamic> json) => PartnerInvite(
    id: json['id'] as String,
    code: json['code'] as String,
    inviterId: json['inviter_id'] as String,
    inviterName: json['inviter_name'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
    consumedAt: json['consumed_at'] == null
        ? null
        : DateTime.parse(json['consumed_at'] as String),
  );
}

class Session {
  const Session({required this.accessToken, required this.expiresAt});

  final String accessToken;

  /// Unix timestamp en segundos. El backend no expone refresh token: cuando
  /// vence, cualquier request devuelve 401 y hay que loguearse de nuevo.
  final int expiresAt;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    accessToken: json['accessToken'] as String,
    expiresAt: json['expiresAt'] as int,
  );
}

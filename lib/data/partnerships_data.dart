import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/partner_invite.dart';
import '../models/partnership.dart';
import '../models/shared_expense.dart';

/// Contrato de la capa de datos del vínculo entre usuarios (spec 14). Permite
/// inyectar dobles en los tests sin depender del SDK real.
abstract interface class PartnershipsDataSource {
  /// Vínculo ACTIVO del usuario actual (o `null` si no tiene).
  Future<Partnership?> current();

  /// Invite pendiente vigente del usuario actual (o `null`).
  Future<PartnerInvite?> pendingInvite();

  /// Genera (o reusa) el código de invitación del usuario actual.
  Future<PartnerInvite> createInvite();

  /// Acepta un código y crea el vínculo. Lanza [PartnerInviteException]
  /// con un código de error de negocio ante fallos previsibles.
  Future<Partnership> acceptInvite(String code);

  /// Desvincula (soft-unlink) el vínculo [id]; conserva el histórico.
  Future<void> unlink(String id);

  /// Gastos de vínculos ya desvinculados (histórico archivado, solo lectura).
  Future<List<SharedExpense>> archivedExpenses();
}

/// Error de negocio al aceptar un invite. [code] es la etiqueta que emite la
/// RPC (`invite_invalid`, `invite_used`, `invite_expired`, `invite_self`,
/// `already_linked`, ...); la UI lo traduce a un mensaje claro.
class PartnerInviteException implements Exception {
  const PartnerInviteException(this.code);
  final String code;
  @override
  String toString() => 'PartnerInviteException($code)';
}

/// Acceso al vínculo vía el SDK de Supabase. La creación/aceptación pasa por
/// RPCs `security definer`; la lectura y el soft-unlink por RLS de miembros.
class PartnershipsData implements PartnershipsDataSource {
  PartnershipsData(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<Partnership?> current() async {
    final rows = await _client
        .from('partnerships')
        .select()
        .isFilter('unlinked_at', null)
        .limit(1);
    if (rows.isEmpty) return null;
    return Partnership.fromJson(rows.first);
  }

  @override
  Future<PartnerInvite?> pendingInvite() async {
    final rows = await _client
        .from('partner_invites')
        .select()
        .eq('inviter_id', _userId)
        .isFilter('consumed_at', null)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final invite = PartnerInvite.fromJson(rows.first);
    return invite.isPending ? invite : null;
  }

  @override
  Future<PartnerInvite> createInvite() async {
    final row = await _client.rpc('create_partner_invite');
    return PartnerInvite.fromJson(_asMap(row));
  }

  @override
  Future<Partnership> acceptInvite(String code) async {
    try {
      final row = await _client.rpc(
        'accept_partner_invite',
        params: {'p_code': code},
      );
      return Partnership.fromJson(_asMap(row));
    } on PostgrestException catch (e) {
      throw PartnerInviteException(_errorCode(e.message));
    }
  }

  @override
  Future<void> unlink(String id) async {
    await _client
        .from('partnerships')
        .update({'unlinked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  @override
  Future<List<SharedExpense>> archivedExpenses() async {
    // Ids de vínculos archivados del usuario, luego sus gastos.
    final partnerships = await _client
        .from('partnerships')
        .select('id')
        .not('unlinked_at', 'is', null);
    final ids = partnerships.map((p) => p['id'] as String).toList();
    if (ids.isEmpty) return [];
    final rows = await _client
        .from('shared_expenses')
        .select()
        .inFilter('partnership_id', ids)
        .order('date', ascending: false);
    return rows.map((e) => SharedExpense.fromJson(e)).toList();
  }

  /// Una RPC que devuelve un `record`/tabla puede llegar como `Map` (single) o
  /// como `List` con una fila; normalizamos a `Map`.
  Map<String, dynamic> _asMap(dynamic row) {
    if (row is List) return Map<String, dynamic>.from(row.first as Map);
    return Map<String, dynamic>.from(row as Map);
  }

  /// Extrae la etiqueta de error que levanta la RPC (`raise exception 'x'`).
  /// Postgres la envuelve en un mensaje; nos quedamos con la palabra clave.
  String _errorCode(String message) {
    final known = [
      'invite_invalid',
      'invite_used',
      'invite_expired',
      'invite_self',
      'already_linked',
      'not_authenticated',
    ];
    for (final k in known) {
      if (message.contains(k)) return k;
    }
    return 'unknown';
  }
}

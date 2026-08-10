import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bill_reminder.dart';

/// Contrato de la capa de datos de recordatorios de facturas (spec 16).
/// Permite inyectar dobles en los tests sin depender del SDK real.
abstract interface class BillRemindersDataSource {
  /// Todos los recordatorios del usuario (RLS aísla por `user_id`).
  Future<List<BillReminder>> list();

  Future<BillReminder> create(BillReminder reminder);

  Future<BillReminder> update(BillReminder reminder);

  Future<void> delete(String id);

  /// Marca el recordatorio como pagado en [cycle] (`YYYY-MM`). Si el
  /// recordatorio no repite mensualmente, además lo desactiva (`active=false`)
  /// para que no se reprograme.
  Future<BillReminder> markPaid(String id, String cycle);

  /// Reactiva los recordatorios `repeat_monthly` cuyo `paid_cycle` quedó en un
  /// ciclo anterior a [currentCycle]: limpia `paid_cycle` (vuelven a "activo del
  /// ciclo actual"). Devuelve los recordatorios afectados (ya reseteados).
  Future<List<BillReminder>> rollToNewCycle(String currentCycle);
}

/// Acceso a `bill_reminders` vía el SDK de Supabase. RLS (`auth.uid() =
/// user_id`) aísla por usuario; seteamos `user_id` en el insert para el
/// `with check`.
class BillRemindersData implements BillRemindersDataSource {
  BillRemindersData(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<BillReminder>> list() async {
    final rows = await _client
        .from('bill_reminders')
        .select()
        .order('start_day', ascending: true);
    return rows.map((e) => BillReminder.fromJson(e)).toList();
  }

  @override
  Future<BillReminder> create(BillReminder reminder) async {
    final row = await _client
        .from('bill_reminders')
        .insert({...reminder.toCreateJson(), 'user_id': _userId})
        .select()
        .single();
    return BillReminder.fromJson(row);
  }

  @override
  Future<BillReminder> update(BillReminder reminder) async {
    final row = await _client
        .from('bill_reminders')
        .update(reminder.toUpdateJson())
        .eq('id', reminder.id)
        .select()
        .single();
    return BillReminder.fromJson(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('bill_reminders').delete().eq('id', id);
  }

  @override
  Future<BillReminder> markPaid(String id, String cycle) async {
    // Necesitamos saber si repite para decidir si desactivarlo.
    final current = await _client
        .from('bill_reminders')
        .select('repeat_monthly')
        .eq('id', id)
        .single();
    final repeatMonthly = current['repeat_monthly'] as bool;
    final row = await _client
        .from('bill_reminders')
        .update({
          'paid_cycle': cycle,
          if (!repeatMonthly) 'active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return BillReminder.fromJson(row);
  }

  @override
  Future<List<BillReminder>> rollToNewCycle(String currentCycle) async {
    final rows = await _client
        .from('bill_reminders')
        .update({'paid_cycle': null, 'updated_at': DateTime.now().toIso8601String()})
        .eq('repeat_monthly', true)
        .not('paid_cycle', 'is', null)
        .lt('paid_cycle', currentCycle) // 'YYYY-MM' ordena lexicográficamente
        .select();
    return rows.map((e) => BillReminder.fromJson(e)).toList();
  }
}

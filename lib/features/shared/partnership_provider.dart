import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/partnerships_data.dart';
import '../../models/partner_invite.dart';
import '../../models/partnership.dart';
import '../../models/shared_expense.dart';
import '../../providers/core_providers.dart';

/// Vínculo ACTIVO del usuario actual (o `null` si no está vinculado).
class PartnershipNotifier extends AsyncNotifier<Partnership?> {
  late final PartnershipsDataSource _data;

  @override
  Future<Partnership?> build() async {
    _data = ref.watch(partnershipsDataProvider);
    return _data.current();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _data.current());
  }

  /// Acepta un código y refresca el vínculo. Propaga [PartnerInviteException].
  Future<Partnership> accept(String code) async {
    final partnership = await _data.acceptInvite(code);
    await refresh();
    ref.invalidate(pendingInviteProvider);
    return partnership;
  }

  /// Desvincula (soft-unlink) y vuelve al estado sin vínculo.
  Future<void> unlink(String id) async {
    await _data.unlink(id);
    await refresh();
    // Los gastos del vínculo pasan a ser histórico archivado.
    ref.invalidate(archivedExpensesProvider);
  }
}

final partnershipProvider =
    AsyncNotifierProvider<PartnershipNotifier, Partnership?>(
  PartnershipNotifier.new,
);

/// Invite pendiente vigente del usuario actual (o `null`).
class PendingInviteNotifier extends AsyncNotifier<PartnerInvite?> {
  late final PartnershipsDataSource _data;

  @override
  Future<PartnerInvite?> build() async {
    _data = ref.watch(partnershipsDataProvider);
    return _data.pendingInvite();
  }

  /// Genera (o reusa) el código y actualiza el estado.
  Future<PartnerInvite> generate() async {
    final invite = await _data.createInvite();
    state = AsyncData(invite);
    return invite;
  }
}

final pendingInviteProvider =
    AsyncNotifierProvider<PendingInviteNotifier, PartnerInvite?>(
  PendingInviteNotifier.new,
);

/// Gastos de vínculos ya desvinculados (histórico archivado, solo lectura).
final archivedExpensesProvider = FutureProvider<List<SharedExpense>>((ref) {
  return ref.watch(partnershipsDataProvider).archivedExpenses();
});

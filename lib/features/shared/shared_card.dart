import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/expense.dart' show formatDateEs;
import '../../models/partnership.dart';
import '../../models/shared_expense.dart';
import '../../theme/app_palette.dart';
import '../../utils/format.dart';
import '../month/month_provider.dart';
import 'link_dialogs.dart';
import 'partnership_provider.dart';
import 'shared_balance.dart';
import 'shared_expense_form.dart';
import 'shared_expenses_provider.dart';

/// Card 2 del carrusel (spec 14): gastos compartidos.
///   - Sin vínculo: estado vacío con *Generar código* / *Ingresar código*.
///   - Con vínculo: encabezado + balance + lista (se completa en el paso 8).
///
/// Ocupa el alto fijo del carrusel; el contenido variable resuelve con scroll
/// interno propio.
class SharedCard extends ConsumerWidget {
  const SharedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnershipAsync = ref.watch(partnershipProvider);

    return _CardShell(
      child: partnershipAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'No se pudo cargar el vínculo.',
            style: TextStyle(color: context.palette.textMuted),
          ),
        ),
        data: (partnership) {
          if (partnership == null) {
            return const _EmptyState();
          }
          return _LinkedState(partnership: partnership);
        },
      ),
    );
  }
}

/// Estado vacío: sin vínculo. Dos acciones para crear el vínculo 1-a-1.
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingInviteProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'COMPARTIDO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: context.palette.textMuted,
              ),
            ),
            const Spacer(),
            if (pending != null)
              TextButton(
                onPressed: () => showGenerateCodeSheet(context, ref),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Ver código: ${pending.code}',
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const Spacer(),
        Icon(Icons.group_outlined,
            size: 40, color: context.palette.textMuted.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Text(
          'Compartí gastos con otra persona',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.palette.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Generá un código o ingresá el que te compartieron.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textMuted, fontSize: 13),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => showGenerateCodeSheet(context, ref),
                child: const Text('Generar código'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => showEnterCodeSheet(context, ref),
                child: const Text('Ingresar código'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Estado vinculado: encabezado "Compartido con {nombre}", TOTAL COMPARTIDO del
/// mes, balance informativo y **lista scrolleable interna** de movimientos.
/// Todo dentro del alto fijo del carrusel; solo la lista scrollea.
class _LinkedState extends ConsumerWidget {
  const _LinkedState({required this.partnership});

  final Partnership partnership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = Supabase.instance.client.auth.currentUser!.id;
    final month = ref.watch(selectedMonthProvider);
    final partnerName = partnership.partnerName(me);
    final partnerId = partnership.partnerId(me);
    final arg = (partnershipId: partnership.id, month: month);
    final expensesAsync = ref.watch(sharedExpensesProvider(arg));
    final expenses = expensesAsync.valueOrNull ?? const <SharedExpense>[];
    final balance = summarize(expenses, me: me, partnerName: partnerName);

    final notifier = ref.read(sharedExpensesProvider(arg).notifier);

    void openCreate() {
      showSharedExpenseSheet(
        context,
        meId: me,
        partnerId: partnerId,
        partnerName: partnerName,
        onSubmit: (description, amount, date, paidBy) {
          notifier.create(
            description: description,
            amount: amount,
            date: date,
            paidBy: paidBy,
          );
        },
      );
    }

    void openEdit(SharedExpense e) {
      showSharedExpenseSheet(
        context,
        meId: me,
        partnerId: partnerId,
        partnerName: partnerName,
        existing: e,
        onSubmit: (description, amount, date, paidBy) {
          notifier.updateExpense(
            e.id,
            description: description,
            amount: amount,
            date: date,
            paidBy: paidBy,
          );
        },
        onDelete: () async {
          final confirmed = await _confirmDeleteShared(context, e);
          if (confirmed) notifier.delete(e.id);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado fijo.
        Row(
          children: [
            Expanded(
              child: Text(
                'Compartido con $partnerName',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.palette.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _AddButton(onPressed: openCreate),
            _LinkMenu(partnership: partnership),
          ],
        ),
        const SizedBox(height: 12),
        // TOTAL COMPARTIDO + balance (fijos).
        Text('TOTAL COMPARTIDO DEL MES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: context.palette.textMuted,
            )),
        const SizedBox(height: 2),
        Text(formatMoney(balance.total),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Vos ${formatMoney(balance.paidByMe)} · '
          '$partnerName ${formatMoney(balance.paidByPartner)} · '
          'Diferencia ${formatMoney(balance.difference)}',
          style: TextStyle(fontSize: 12, color: context.palette.textMuted),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: context.palette.line),
        // Lista scrolleable interna (ocupa el alto restante del alto fijo).
        Expanded(
          child: expensesAsync.isLoading && !expensesAsync.hasValue
              ? const Center(child: CircularProgressIndicator())
              : expenses.isEmpty
                  ? Center(
                      child: Text(
                        'Sin gastos compartidos este mes.',
                        style: TextStyle(color: context.palette.textMuted, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: expenses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, i) => _SharedExpenseTile(
                        expense: expenses[i],
                        me: me,
                        partnerName: partnerName,
                        onTap: () => openEdit(expenses[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

/// Fila de un gasto compartido: descripción, quién pagó y fecha; monto a la
/// derecha. Solo lectura en este paso (editar/borrar entra en el paso 9).
class _SharedExpenseTile extends StatelessWidget {
  const _SharedExpenseTile({
    required this.expense,
    required this.me,
    required this.partnerName,
    required this.onTap,
  });

  final SharedExpense expense;
  final String me;
  final String partnerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paidByLabel = expense.paidBy == me ? 'Vos' : partnerName;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Pagó $paidByLabel · ${formatDateEs(expense.date)}',
                  style: TextStyle(fontSize: 12, color: context.palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatMoney(expense.amount),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      ),
    );
  }
}

/// Botón "+" compacto para agregar un gasto compartido.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.ink,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.add, color: context.palette.inkText, size: 20),
        ),
      ),
    );
  }
}

/// Menú de gestión del vínculo (card 2): desvincular (soft-unlink, con
/// confirmación) y ver el histórico archivado.
class _LinkMenu extends ConsumerWidget {
  const _LinkMenu({required this.partnership});

  final Partnership partnership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Gestionar vínculo',
      position: PopupMenuPosition.under,
      icon: Icon(Icons.more_vert, color: context.palette.textMuted),
      onSelected: (value) async {
        switch (value) {
          case 'archived':
            showArchivedHistorySheet(context);
          case 'unlink':
            final confirmed = await _confirmUnlink(context, partnership);
            if (confirmed) {
              await ref
                  .read(partnershipProvider.notifier)
                  .unlink(partnership.id);
            }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'archived',
          child: Row(
            children: [
              Icon(Icons.history, size: 18),
              SizedBox(width: 10),
              Text('Ver histórico archivado'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'unlink',
          child: Row(
            children: [
              Icon(Icons.link_off, size: 18, color: context.palette.alert),
              const SizedBox(width: 10),
              const Text('Desvincular'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirmación de desvinculación. El soft-unlink conserva los gastos.
Future<bool> _confirmUnlink(BuildContext context, Partnership p) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Desvincular'),
      content: const Text(
        'Se cortará el vínculo. Los gastos compartidos se conservan y podrás '
        'verlos en el histórico archivado. Podés volver a vincularte más adelante.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: context.palette.alert,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Desvincular'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Sheet de solo lectura con los gastos de vínculos ya desvinculados.
Future<void> showArchivedHistorySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _ArchivedHistoryBody(),
  );
}

class _ArchivedHistoryBody extends ConsumerWidget {
  const _ArchivedHistoryBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = Supabase.instance.client.auth.currentUser!.id;
    final async = ref.watch(archivedExpensesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Histórico archivado',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('No se pudo cargar el histórico.',
                      style: TextStyle(color: context.palette.textMuted)),
                ),
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return Center(
                      child: Text('No hay gastos archivados.',
                          style: TextStyle(color: context.palette.textMuted)),
                    );
                  }
                  return ListView.separated(
                    itemCount: expenses.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: context.palette.line),
                    itemBuilder: (context, i) {
                      final e = expenses[i];
                      final paidBy = e.paidBy == me ? 'Vos' : 'La otra persona';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.description,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pagó $paidBy · ${formatDateEs(e.date)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.palette.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(formatMoney(e.amount),
                                style:
                                    const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmación de borrado de un gasto compartido. Devuelve `true` si confirma.
Future<bool> _confirmDeleteShared(BuildContext context, SharedExpense e) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Borrar gasto compartido'),
      content: Text(
        "¿Confirmás borrar '${e.description}' de ${formatMoney(e.amount)}?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: context.palette.alert,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Contenedor con el mismo estilo visual que la `DonutCard`.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.line),
      ),
      child: child,
    );
  }
}

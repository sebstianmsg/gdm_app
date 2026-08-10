import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bill_reminder.dart';
import '../../theme/app_palette.dart';
import '../../utils/format.dart';
import 'reminder_form.dart';
import 'reminder_pay.dart';
import 'reminders_provider.dart';

/// Verde del botón PAGO (spec 16). Fijo para garantizar contraste con el texto
/// blanco en ambos temas (el `success` de la paleta es un verde neón).
const Color _kPagoGreen = Color(0xFF2E7D32);

/// Ícono del tipo de recordatorio (solo visual).
IconData iconForKind(ReminderKind kind) {
  switch (kind) {
    case ReminderKind.service:
      return Icons.receipt_long;
    case ReminderKind.card:
      return Icons.credit_card;
    case ReminderKind.debt:
      return Icons.account_balance;
  }
}

/// Card 3 del carrusel (spec 16): recordatorios de facturas a pagar. Reemplaza
/// el placeholder "Próximamente". Encabezado + botón `+`, lista scrolleable
/// interna dentro del alto fijo, estado vacío, y cada fila con su botón PAGO.
class RemindersCard extends ConsumerWidget {
  const RemindersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classifiedRemindersProvider);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado fijo.
          Row(
            children: [
              Text(
                'RECORDATORIOS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.palette.textMuted,
                ),
              ),
              const Spacer(),
              _AddButton(onPressed: () => showReminderForm(context, ref)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: context.palette.line),
          // Lista scrolleable interna (ocupa el alto restante del alto fijo).
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'No se pudieron cargar los recordatorios.',
                  style: TextStyle(color: context.palette.textMuted, fontSize: 13),
                ),
              ),
              data: (views) {
                if (views.isEmpty) return const _EmptyState();
                return ListView.separated(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: views.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, i) => _ReminderTile(view: views[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.textMuted;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none,
              size: 40, color: muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Sin recordatorios',
            style: TextStyle(fontWeight: FontWeight.w600, color: context.palette.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Tocá + para agregar una factura a pagar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Fila de un recordatorio. Al tocar (fuera del botón PAGO) abre el formulario
/// para editar/borrar. Si está pagado este ciclo, se muestra "apagado" con la
/// etiqueta "Pagado" en vez del botón PAGO.
class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.view});

  final ReminderView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = view.reminder;
    final isPaid = view.status == ReminderStatus.paidThisCycle;
    final dimmed = isPaid || view.status == ReminderStatus.inactive;
    final baseColor = dimmed
        ? context.palette.textMuted.withValues(alpha: 0.7)
        : context.palette.text;

    return InkWell(
      onTap: () => showReminderForm(context, ref, existing: r),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(iconForKind(r.kind), size: 22, color: baseColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: TextStyle(fontWeight: FontWeight.w600, color: baseColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${kindLabel(r.kind)} · ${formatMoney(r.amount)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Inicio día ${r.startDay} · Vence día ${r.dueDay}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.palette.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isPaid)
              _PaidBadge()
            else
              _PagoButton(reminder: r),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta "Pagado" (recordatorio ya pagado en el ciclo actual).
class _PaidBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.palette.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: context.palette.textMuted),
          const SizedBox(width: 4),
          Text(
            'Pagado',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón PAGO (verde, texto blanco). La acción se cablea en el paso 11.
class _PagoButton extends ConsumerWidget {
  const _PagoButton({required this.reminder});

  final BillReminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: _kPagoGreen,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => payReminder(context, ref, reminder),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            'PAGO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón "+" compacto (mismo estilo que la card 2).
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

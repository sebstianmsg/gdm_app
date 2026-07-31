import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../utils/format.dart';
import '../auth/auth_provider.dart';
import '../categories/categories_modal.dart';
import '../categories/categories_provider.dart';
import '../expenses/delete_expense_dialog.dart';
import '../expenses/expense_form.dart';
import '../expenses/expenses_provider.dart';
import 'category_summary.dart';
import 'donut_card.dart';
import 'month_provider.dart';
import 'movements_card.dart';

/// Pantalla principal. Réplica de `.wrap` en `public/index.html`: header,
/// selector de mes + total, donut por categoría, movimientos.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final expensesAsync = ref.watch(expensesProvider(month));
    final categories = categoriesAsync.valueOrNull ?? const [];
    final expenses = expensesAsync.valueOrNull ?? const [];
    final total = expenses.fold<double>(0, (a, e) => a + e.amount);
    final summaries = summarizeByCategory(expenses, categories);
    final isLoading = expensesAsync.isLoading && !expensesAsync.hasValue;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(categoriesProvider.notifier).refresh();
            await ref.read(expensesProvider(month).notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Header(
                onLogout: () async {
                  final confirmed = await _confirmLogout(context);
                  if (confirmed) {
                    ref.read(authProvider.notifier).logout();
                  }
                },
              ),
              const SizedBox(height: 20),
              _MonthCard(month: month, total: total),
              const SizedBox(height: 16),
              DonutCard(
                summaries: summaries,
                onManageCategories: () => showCategoriesModal(context),
                onAddPressed: () => showAddExpenseSheet(
                  context,
                  categories: categories,
                  onSubmit: (description, amount, date, categoryId) {
                    ref
                        .read(expensesProvider(month).notifier)
                        .create(
                          description: description,
                          amount: amount,
                          date: date,
                          categoryId: categoryId,
                        );
                  },
                ),
              ),
              const SizedBox(height: 16),
              MovementsCard(
                expenses: expenses,
                categories: categories,
                isLoading: isLoading,
                onSave: (id, description, amount, date, categoryId) {
                  ref
                      .read(expensesProvider(month).notifier)
                      .updateExpense(
                        id,
                        description: description,
                        amount: amount,
                        date: date,
                        categoryId: categoryId,
                      );
                },
                onDelete: (expense) async {
                  final confirmed = await showDeleteExpenseDialog(context, expense);
                  if (confirmed) {
                    ref.read(expensesProvider(month).notifier).delete(expense.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muestra un diálogo de confirmación antes de cerrar sesión.
/// Devuelve `true` solo si el usuario confirma; `false` al cancelar o descartar.
Future<bool> _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Cerrar sesión?'),
      content: const Text('Tu sesión se cerrará y volverás al login.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: context.palette.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Resuelve el identificador de la cuenta a mostrar en el header, con la
/// cascada: `user_metadata['full_name']` → `user_metadata['name']` (típico de
/// Google) → parte del `email` anterior al `@`. Devuelve cadena vacía si no
/// hay usuario ni datos utilizables (el widget entonces no se muestra).
///
/// Expuesto con [visibleForTesting] para poder probar la cascada por unidad;
/// su uso está pensado solo dentro de este archivo.
@visibleForTesting
String accountLabel(User? user) {
  if (user == null) return '';

  final metadata = user.userMetadata;
  final fullName = (metadata?['full_name'] as String?)?.trim();
  if (fullName != null && fullName.isNotEmpty) return fullName;

  final name = (metadata?['name'] as String?)?.trim();
  if (name != null && name.isNotEmpty) return name;

  final email = user.email?.trim() ?? '';
  if (email.isEmpty) return '';
  final atIndex = email.indexOf('@');
  return atIndex >= 0 ? email.substring(0, atIndex) : email;
}

class _Header extends ConsumerWidget {
  const _Header({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = accountLabel(Supabase.instance.client.auth.currentUser);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LIBRO DE GASTOS', style: AppTextStyles.eyebrow(context)),
              const SizedBox(height: 4),
              Text('Mis gastos', style: AppTextStyles.h1(context)),
            ],
          ),
        ),
        // Arriba a la derecha: solo el ícono de usuario, disparador del menú
        // de cuenta (nombre + selector de tema + cerrar sesión).
        PopupMenuButton<void>(
          tooltip: 'Cuenta',
          position: PopupMenuPosition.under,
          icon: Icon(Icons.person, color: context.palette.textMuted),
          itemBuilder: (context) => [
            // (a) Encabezado no seleccionable con el nombre de cuenta.
            PopupMenuItem<void>(
              enabled: false,
              child: Text(
                name.isEmpty ? 'Cuenta' : name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.palette.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const PopupMenuDivider(),
            // (b) Selector cápsula sol/luna (cambia el tema al instante y deja
            // el menú abierto).
            PopupMenuItem<void>(
              enabled: false,
              child: _ThemeCapsule(ref: ref),
            ),
            const PopupMenuDivider(),
            // (c) Cerrar sesión (conserva la confirmación del spec 07).
            PopupMenuItem<void>(
              onTap: onLogout,
              child: Row(
                children: [
                  Icon(Icons.power_settings_new,
                      size: 18, color: context.palette.text),
                  const SizedBox(width: 10),
                  const Text('Cerrar sesión'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Cápsula de dos estados: sol (claro) y luna (oscuro). Refleja el `themeMode`
/// activo y al tocar cambia el tema al instante. Vive dentro del menú de
/// usuario; usa un `StatefulBuilder` + `GestureDetector` propio para alternar
/// sin cerrar el menú.
class _ThemeCapsule extends StatelessWidget {
  const _ThemeCapsule({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        // El menú vive en un overlay, fuera del build de `_Header`; leemos el
        // valor actual (no `watch`) y repintamos localmente al alternar.
        final palette = context.palette;
        final mode = ref.read(themeProvider);
        final isDark = mode == ThemeMode.dark;

        Widget half(IconData icon, bool selected, ThemeMode target) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(themeProvider.notifier).setMode(target);
              // Repinta la cápsula sin cerrar el menú.
              setLocalState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? palette.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? palette.inkText : palette.textMuted,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: palette.surface2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              half(Icons.light_mode, !isDark, ThemeMode.light),
              half(Icons.dark_mode, isDark, ThemeMode.dark),
            ],
          ),
        );
      },
    );
  }
}

class _MonthCard extends ConsumerWidget {
  const _MonthCard({required this.month, required this.total});

  final DateTime month;
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.line),
      ),
      child: Row(
        children: [
          _MonthPickerButton(
            icon: Icons.chevron_left,
            onTap: () => ref.read(selectedMonthProvider.notifier).previous(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatMonthLabel(month),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          _MonthPickerButton(
            icon: Icons.chevron_right,
            onTap: () => ref.read(selectedMonthProvider.notifier).next(),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('TOTAL DEL MES', style: AppTextStyles.sectionLabel(context)),
              Text(formatMoney(total), style: AppTextStyles.total(context)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthPickerButton extends StatelessWidget {
  const _MonthPickerButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface2,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 20)),
      ),
    );
  }
}

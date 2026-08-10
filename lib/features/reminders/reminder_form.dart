import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bill_reminder.dart';
import '../../models/category.dart';
import '../../models/expense.dart' show formatDateEs;
import '../../theme/app_palette.dart';
import '../../theme/app_radius.dart';
import '../../providers/core_providers.dart';
import '../categories/categories_provider.dart';
import 'reminder_scheduling.dart';
import 'reminders_provider.dart';

/// Abre el formulario de alta/edición/borrado de un recordatorio (spec 16,
/// paso 10). Patrón de `expense_form.dart`. [existing] no nulo => modo edición
/// (permite borrar). Al guardar persiste y (re)programa la notificación; al
/// borrar cancela la notificación.
Future<void> showReminderForm(
  BuildContext context,
  WidgetRef ref, {
  BillReminder? existing,
}) {
  final categories = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ReminderForm(existing: existing, categories: categories),
    ),
  );
}

class _ReminderForm extends ConsumerStatefulWidget {
  const _ReminderForm({required this.existing, required this.categories});

  final BillReminder? existing;
  final List<Category> categories;

  @override
  ConsumerState<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends ConsumerState<_ReminderForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late ReminderKind _kind;
  String? _categoryId;
  late DateTime _startDate;
  late DateTime _dueDate;
  late TimeOfDay _time;
  late bool _persistent;
  late bool _repeatMonthly;
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _nameController = TextEditingController(text: e?.name ?? '');
    _amountController = TextEditingController(
      text: e == null ? '' : _formatAmountInput(e.amount),
    );
    _kind = e?.kind ?? ReminderKind.service;
    _categoryId = e?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    // Reconstruye fechas concretas en el mes actual a partir del día persistido.
    _startDate = e == null
        ? now
        : _clampDay(now.year, now.month, e.startDay);
    _dueDate = e == null
        ? now
        : _clampDay(now.year, now.month, e.dueDay);
    _time = e == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: e.notifyHour, minute: e.notifyMinute);
    _persistent = e?.persistent ?? false;
    _repeatMonthly = e?.repeatMonthly ?? true;
  }

  static DateTime _clampDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  static String _formatAmountInput(double amount) =>
      amount == amount.roundToDouble() ? amount.toInt().toString() : amount.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _dueDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (_nameController.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        _categoryId == null) {
      setState(() => _error = 'Completá nombre, monto (> 0) y categoría.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final reminder = BillReminder(
      id: widget.existing?.id ?? '',
      name: _nameController.text.trim(),
      kind: _kind,
      amount: amount,
      categoryId: _categoryId!,
      startDay: _startDate.day,
      dueDay: _dueDate.day,
      notifyHour: _time.hour,
      notifyMinute: _time.minute,
      persistent: _persistent,
      repeatMonthly: _repeatMonthly,
      paidCycle: widget.existing?.paidCycle,
      active: widget.existing?.active ?? true,
    );

    final notifier = ref.read(billRemindersProvider.notifier);
    final saved = _isEditing
        ? await notifier.updateReminder(reminder)
        : await notifier.create(reminder);

    // (Re)programa la notificación del recordatorio guardado. Avisa si los
    // permisos están denegados, pero no bloquea el guardado (la card 3 sigue
    // funcionando como respaldo visual).
    final warning = await reprogramReminder(ref, saved);
    if (!mounted) return;
    navigator.pop();
    if (warning != null) {
      messenger.showSnackBar(SnackBar(content: Text(warning)));
    }
  }

  Future<void> _delete() async {
    final r = widget.existing;
    if (r == null) return;
    final notifier = ref.read(billRemindersProvider.notifier);
    await ref.read(reminderNotificationsProvider).cancel(r);
    await notifier.delete(r.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Editar recordatorio' : 'Nuevo recordatorio',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: palette.alert),
                    tooltip: 'Borrar',
                    onPressed: _saving ? null : _delete,
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Nombre (ej: Luz)'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Text('Tipo', style: TextStyle(color: palette.textMuted)),
            const SizedBox(height: 8),
            _KindToggle(
              value: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Monto'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            _FieldButton(
              label: 'Fecha de inicio',
              value: formatDateEs(_startDate),
              icon: Icons.event,
              onTap: () => _pickDate(true),
            ),
            const SizedBox(height: 8),
            _FieldButton(
              label: 'Vencimiento (informativo)',
              value: formatDateEs(_dueDate),
              icon: Icons.event_available,
              onTap: () => _pickDate(false),
            ),
            const SizedBox(height: 8),
            _FieldButton(
              label: 'Hora de la notificación',
              value: _time.format(context),
              icon: Icons.access_time,
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notificación persistente'),
              subtitle: const Text('No se descarta deslizando'),
              value: _persistent,
              onChanged: (v) => setState(() => _persistent = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repetir todos los meses'),
              value: _repeatMonthly,
              onChanged: (v) => setState(() => _repeatMonthly = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: palette.alert)),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector de tres estados: Servicio / Tarjeta / Deuda (solo visual).
class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.value, required this.onChanged});

  final ReminderKind value;
  final ValueChanged<ReminderKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget option(ReminderKind kind) {
      final selected = kind == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(kind),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? palette.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              kindLabel(kind),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? palette.inkText : palette.textMuted,
              ),
            ),
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
        children: ReminderKind.values.map(option).toList(),
      ),
    );
  }
}

/// Botón de campo con etiqueta + valor (fecha/hora), estilo outlined.
class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.palette.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: context.palette.textMuted)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

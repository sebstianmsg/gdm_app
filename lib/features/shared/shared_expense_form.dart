import 'package:flutter/material.dart';

import '../../models/expense.dart' show formatDateEs;
import '../../models/shared_expense.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radius.dart';

/// Modal de alta/edición de un gasto compartido (spec 14), patrón de
/// `expense_form.dart`: descripción, monto, fecha y **toggle "¿Quién pagó?"**
/// (Vos / {nombre}). Sin categoría (el MVP no categoriza compartidos).
///
/// [existing] no nulo => modo edición (muestra "Guardar" y permite borrar).
Future<void> showSharedExpenseSheet(
  BuildContext context, {
  required String meId,
  required String partnerId,
  required String partnerName,
  SharedExpense? existing,
  required void Function(
    String description,
    double amount,
    DateTime date,
    String paidBy,
  ) onSubmit,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _SharedExpenseForm(
        meId: meId,
        partnerId: partnerId,
        partnerName: partnerName,
        existing: existing,
        onSubmit: onSubmit,
        onDelete: onDelete,
      ),
    ),
  );
}

class _SharedExpenseForm extends StatefulWidget {
  const _SharedExpenseForm({
    required this.meId,
    required this.partnerId,
    required this.partnerName,
    required this.existing,
    required this.onSubmit,
    required this.onDelete,
  });

  final String meId;
  final String partnerId;
  final String partnerName;
  final SharedExpense? existing;
  final void Function(String description, double amount, DateTime date, String paidBy)
      onSubmit;
  final VoidCallback? onDelete;

  @override
  State<_SharedExpenseForm> createState() => _SharedExpenseFormState();
}

class _SharedExpenseFormState extends State<_SharedExpenseForm> {
  late final TextEditingController _descController;
  late final TextEditingController _amountController;
  late DateTime _date;
  late String _paidBy;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _descController = TextEditingController(text: e?.description ?? '');
    _amountController = TextEditingController(
      text: e == null ? '' : _formatAmountInput(e.amount),
    );
    _date = e?.date ?? DateTime.now();
    _paidBy = e?.paidBy ?? widget.meId;
  }

  static String _formatAmountInput(double amount) {
    // Sin separador de miles ni símbolo, para editar cómodo.
    return amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toString();
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (_descController.text.trim().isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Completá descripción, monto y fecha.');
      return;
    }
    widget.onSubmit(_descController.text.trim(), amount, _date, _paidBy);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEditing ? 'Editar gasto compartido' : 'Agregar gasto compartido',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (_isEditing && widget.onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: context.palette.alert),
                  tooltip: 'Borrar',
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete!();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(hintText: 'Descripción (ej: súper)'),
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Monto'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _pickDate,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(formatDateEs(_date)),
            ),
          ),
          const SizedBox(height: 14),
          Text('¿Quién pagó?', style: TextStyle(color: context.palette.textMuted)),
          const SizedBox(height: 8),
          _PaidByToggle(
            meLabel: 'Vos',
            partnerLabel: widget.partnerName,
            paidByMe: _paidBy == widget.meId,
            onChanged: (byMe) => setState(
              () => _paidBy = byMe ? widget.meId : widget.partnerId,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: context.palette.alert)),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _submit,
            child: Text(_isEditing ? 'Guardar' : 'Agregar'),
          ),
        ],
      ),
    );
  }
}

/// Selector de dos estados: Vos / {nombre}. Estilo cápsula, coherente con el
/// selector de tema del home.
class _PaidByToggle extends StatelessWidget {
  const _PaidByToggle({
    required this.meLabel,
    required this.partnerLabel,
    required this.paidByMe,
    required this.onChanged,
  });

  final String meLabel;
  final String partnerLabel;
  final bool paidByMe;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget half(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? palette.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
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
        children: [
          half(meLabel, paidByMe, () => onChanged(true)),
          half(partnerLabel, !paidByMe, () => onChanged(false)),
        ],
      ),
    );
  }
}

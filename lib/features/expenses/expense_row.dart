import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/expense.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/category_chip.dart';

/// Una fila de movimiento. En modo lectura: punto + descripción + chip +
/// monto + lápiz/✕. En modo edición se transforma en inputs inline (mismo
/// comportamiento que `.entry-editing` en `public/js/app.js`).
class ExpenseRow extends StatefulWidget {
  const ExpenseRow({
    super.key,
    required this.expense,
    required this.category,
    required this.categories,
    required this.isEditing,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSave,
    required this.onDelete,
  });

  final Expense expense;
  final Category? category;
  final List<Category> categories;
  final bool isEditing;
  final VoidCallback onStartEdit;
  final VoidCallback onCancelEdit;
  final void Function(String description, double amount, DateTime date, String categoryId)
  onSave;
  final VoidCallback onDelete;

  @override
  State<ExpenseRow> createState() => _ExpenseRowState();
}

class _ExpenseRowState extends State<ExpenseRow> {
  late TextEditingController _descController;
  late TextEditingController _amountController;
  DateTime? _date;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _resetFields();
  }

  @override
  void didUpdateWidget(covariant ExpenseRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && !oldWidget.isEditing) _resetFields();
  }

  void _resetFields() {
    _descController = TextEditingController(text: widget.expense.description);
    _amountController = TextEditingController(
      text: widget.expense.amount.toStringAsFixed(2),
    );
    _date = widget.expense.date;
    _categoryId = widget.expense.categoryId;
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (_descController.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        _date == null ||
        _categoryId == null) {
      return;
    }
    widget.onSave(_descController.text.trim(), amount, _date!, _categoryId!);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Color get _dotColor => widget.category != null
      ? colorFromHex(widget.category!.color)
      : context.palette.textMuted;

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) return _buildEditing();
    return _buildRead();
  }

  Widget _buildRead() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.expense.description,
              style: AppTextStyles.description(context),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (widget.category != null) CategoryChip(category: widget.category!),
          const SizedBox(width: 10),
          Text(formatMoney(widget.expense.amount), style: AppTextStyles.amount(context)),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: context.palette.textMuted),
            onPressed: widget.onStartEdit,
            tooltip: 'Editar',
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: context.palette.textMuted),
            onPressed: widget.onDelete,
            tooltip: 'Borrar',
          ),
        ],
      ),
    );
  }

  Widget _buildEditing() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.palette.ink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _descController,
            decoration: const InputDecoration(hintText: 'Descripción'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'Monto'),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(
                    _date == null ? 'Fecha' : formatDateEs(_date!),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            items: widget.categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.close, color: context.palette.danger),
                onPressed: widget.onCancelEdit,
                tooltip: 'Cancelar',
              ),
              IconButton(
                icon: Icon(Icons.check, color: context.palette.success),
                onPressed: _save,
                tooltip: 'Guardar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/expense.dart' show formatDateEs;
import '../../theme/app_palette.dart';
import '../../theme/app_radius.dart';
import '../../utils/category_keywords.dart';

/// Modal "Agregar gasto". Réplica de `#addExpenseModalOverlay`: descripción,
/// monto, fecha (default hoy), categoría. Preselecciona la categoría por
/// keywords de la descripción (best-effort, solo mientras el usuario no haya
/// tocado el dropdown a mano).
Future<void> showAddExpenseSheet(
  BuildContext context, {
  required List<Category> categories,
  required void Function(String description, double amount, DateTime date, String categoryId)
  onSubmit,
  String? initialDescription,
  double? initialAmount,
  String? initialCategoryId,
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
      child: _AddExpenseForm(
        categories: categories,
        onSubmit: onSubmit,
        initialDescription: initialDescription,
        initialAmount: initialAmount,
        initialCategoryId: initialCategoryId,
      ),
    ),
  );
}

class _AddExpenseForm extends StatefulWidget {
  const _AddExpenseForm({
    required this.categories,
    required this.onSubmit,
    this.initialDescription,
    this.initialAmount,
    this.initialCategoryId,
  });

  final List<Category> categories;
  final void Function(String description, double amount, DateTime date, String categoryId)
  onSubmit;
  final String? initialDescription;
  final double? initialAmount;
  final String? initialCategoryId;

  @override
  State<_AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<_AddExpenseForm> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _categoryId;
  bool _categoryTouchedManually = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Valores iniciales (ej. desde el alta por voz, spec 27). Todos opcionales:
    // sin ellos el form se comporta igual que antes.
    if (widget.initialDescription != null) {
      _descController.text = widget.initialDescription!;
    }
    if (widget.initialAmount != null) {
      final amount = widget.initialAmount!;
      _amountController.text =
          amount == amount.truncateToDouble()
              ? amount.toStringAsFixed(0)
              : amount.toString();
    }
    if (widget.initialCategoryId != null &&
        widget.categories.any((c) => c.id == widget.initialCategoryId)) {
      _categoryId = widget.initialCategoryId;
      // El caller ya resolvió la categoría; no la pisamos por keywords.
      _categoryTouchedManually = true;
    } else if (widget.categories.isNotEmpty) {
      _categoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged(String text) {
    if (_categoryTouchedManually) return;
    final suggestedName = detectCategoryName(text);
    if (suggestedName == null) return;
    for (final c in widget.categories) {
      if (c.name.toLowerCase() == suggestedName.toLowerCase()) {
        setState(() => _categoryId = c.id);
        break;
      }
    }
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
    if (_descController.text.trim().isEmpty || amount == null || amount <= 0 || _categoryId == null) {
      setState(() => _error = 'Completá descripción, monto, fecha y categoría.');
      return;
    }
    widget.onSubmit(_descController.text.trim(), amount, _date, _categoryId!);
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
              const Expanded(
                child: Text('Agregar gasto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(hintText: 'Descripción (ej: nafta)'),
            onChanged: _onDescriptionChanged,
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
            child: Align(alignment: Alignment.centerLeft, child: Text(formatDateEs(_date))),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: widget.categories.any((c) => c.id == _categoryId)
                ? _categoryId
                : null,
            items: widget.categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() {
              _categoryId = v;
              _categoryTouchedManually = true;
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: context.palette.alert)),
          ],
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _submit, child: const Text('Agregar')),
        ],
      ),
    );
  }
}

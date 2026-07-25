import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../widgets/category_chip.dart';
import 'categories_provider.dart';

/// Paleta para el selector de color (incluye los 7 colores default de
/// `sql/schema.sql` + variantes extra).
const _colorPalette = [
  '#FF6B6B', '#FFD93D', '#4D96FF', '#C77DFF', '#6BCB77', '#00C9A7', '#FF9A3C',
  '#4FAE84', '#E86A4D', '#8B968F', '#5C7CFA', '#F783AC',
];

Future<void> showCategoriesModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
    ),
    builder: (context) => const _CategoriesModalBody(),
  );
}

Future<String?> _pickColor(BuildContext context, String current) {
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Elegir color'),
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _colorPalette.map((hex) {
          final color = colorFromHex(hex);
          return GestureDetector(
            onTap: () => Navigator.pop(context, hex),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: hex == current ? Border.all(color: Colors.white, width: 2) : null,
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

class _CategoriesModalBody extends ConsumerStatefulWidget {
  const _CategoriesModalBody();

  @override
  ConsumerState<_CategoriesModalBody> createState() => _CategoriesModalBodyState();
}

class _CategoriesModalBodyState extends ConsumerState<_CategoriesModalBody> {
  final _newNameController = TextEditingController();
  String _newColor = '#4FAE84';
  String? _error;

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ingresá un nombre para la categoría.');
      return;
    }
    setState(() => _error = null);
    await ref.read(categoriesProvider.notifier).create(name: name, color: _newColor);
    _newNameController.clear();
  }

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar categoría'),
        content: Text(
          "Los gastos de esta categoría pasarán a Otros. ¿Confirmás borrar '${category.name}'?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(categoriesProvider.notifier).delete(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Categorías', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: categoriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.alert))),
                  data: (categories) => ListView(
                    controller: scrollController,
                    children: categories.map((c) => _CategoryRow(
                      category: c,
                      onColorTap: () async {
                        final hex = await _pickColor(context, c.color);
                        if (hex != null) {
                          await ref.read(categoriesProvider.notifier).updateCategory(c.id, color: hex);
                        }
                      },
                      onNameChanged: (name) async {
                        if (name.trim().isEmpty) return;
                        await ref.read(categoriesProvider.notifier).updateCategory(c.id, name: name.trim());
                      },
                      onDelete: c.isDeletable ? () => _confirmDelete(c) : null,
                    )).toList(),
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final hex = await _pickColor(context, _newColor);
                      if (hex != null) setState(() => _newColor = hex);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: colorFromHex(_newColor), shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _newNameController,
                      decoration: const InputDecoration(hintText: 'Nombre de categoría'),
                      onSubmitted: (_) => _create(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(onPressed: _create, child: const Text('Agregar')),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.alert)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    required this.category,
    required this.onColorTap,
    required this.onNameChanged,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onColorTap;
  final ValueChanged<String> onNameChanged;
  final VoidCallback? onDelete;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.category.name);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) widget.onNameChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onColorTap,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorFromHex(widget.category.color),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(isDense: true),
              onSubmitted: widget.onNameChanged,
            ),
          ),
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
              onPressed: widget.onDelete,
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radius.dart';
import '../../widgets/category_chip.dart';
import 'categories_provider.dart';
import 'category_editor_modal.dart';
import 'category_icons.dart';

/// Paleta para el selector de color (incluye los 7 colores default de
/// `sql/schema.sql` + variantes extra).
const _colorPalette = [
  // 12 actuales.
  '#FF6B6B', '#FFD93D', '#4D96FF', '#C77DFF', '#6BCB77', '#00C9A7', '#FF9A3C',
  '#4FAE84', '#E86A4D', '#8B968F', '#5C7CFA', '#F783AC',
  // 20 nuevos, distintos y variados.
  '#E64980', '#BE4BDB', '#7950F2', '#4263EB', '#1C7ED6', '#1098AD', '#0CA678',
  '#37B24D', '#74B816', '#F59F00', '#F76707', '#E8590C', '#D6336C', '#AE3EC9',
  '#862E9C', '#364FC7', '#0B7285', '#087F5B', '#2B8A3E', '#5F3DC4',
];

Future<void> showCategoriesModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
    ),
    builder: (context) => const _CategoriesModalBody(),
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
  String _newIcon = 'help';
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
    await ref.read(categoriesProvider.notifier).create(name: name, color: _newColor, icon: _newIcon);
    _newNameController.clear();
  }

  /// Abre el editor para elegir ícono/color (y nombre) del borrador de alta.
  Future<void> _pickNewIconColor(Set<String> usedColors) async {
    final draft = await showCategoryEditor(
      context,
      title: 'Nueva categoría',
      saveLabel: 'Listo',
      initialName: _newNameController.text,
      initialColor: _newColor,
      initialIcon: _newIcon,
      palette: _colorPalette,
      usedColors: usedColors,
    );
    if (draft == null) return;
    setState(() {
      _newColor = draft.color;
      _newIcon = draft.icon;
      _newNameController.text = draft.name;
    });
  }

  Future<void> _editCategory(Category category, Set<String> usedColors) async {
    // Los colores usados por OTRAS categorías se ocultan; el propio sigue visible.
    final usedByOthers = usedColors.difference({category.color.toUpperCase()});
    final draft = await showCategoryEditor(
      context,
      title: 'Editar categoría',
      saveLabel: 'Guardar',
      initialName: category.name,
      initialColor: category.color,
      initialIcon: category.icon,
      palette: _colorPalette,
      usedColors: usedByOthers,
    );
    if (draft == null) return;
    await ref.read(categoriesProvider.notifier).updateCategory(
          category.id,
          name: draft.name,
          color: draft.color,
          icon: draft.icon,
        );
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
            style: ElevatedButton.styleFrom(backgroundColor: context.palette.alert, foregroundColor: Colors.white),
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
    // Colores en uso por las categorías actuales, normalizados a mayúsculas.
    final usedColors = (categoriesAsync.valueOrNull ?? const <Category>[])
        .map((c) => c.color.toUpperCase())
        .toSet();
    // ¿Queda algún color de la paleta sin usar para una categoría nueva?
    final hasFreeColor = _colorPalette.any((hex) => !usedColors.contains(hex.toUpperCase()));

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
                  error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.palette.alert))),
                  data: (categories) => ScrollConfiguration(
                    // Se mantiene el scroll pero se oculta la barra visible.
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: ListView(
                      controller: scrollController,
                      children: categories.map((c) => _CategoryRow(
                        category: c,
                        onEdit: () => _editCategory(c, usedColors),
                        onDelete: c.isDeletable ? () => _confirmDelete(c) : null,
                      )).toList(),
                    ),
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  _CategoryCircle(
                    color: colorFromHex(_newColor),
                    icon: Icons.add,
                    onTap: () => _pickNewIconColor(usedColors),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _newNameController,
                      decoration: const InputDecoration(hintText: 'Nombre de la categoría'),
                      onSubmitted: (_) => _create(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: hasFreeColor ? _create : null,
                    child: const Text('Agregar'),
                  ),
                ],
              ),
              if (!hasFreeColor) ...[
                const SizedBox(height: 8),
                Text('No hay colores libres', style: TextStyle(color: context.palette.alert)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: context.palette.alert)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Círculo de 44px con el color de la categoría y su ícono en blanco.
/// `child` permite sobrescribir el contenido (ej. el `+` de la fila de alta).
class _CategoryCircle extends StatelessWidget {
  const _CategoryCircle({required this.color, required this.icon, this.onTap});

  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _CategoryCircle(
            color: colorFromHex(category.color),
            icon: iconForKey(category.icon),
            onTap: onEdit,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: context.palette.textMuted),
            onPressed: onEdit,
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: context.palette.textMuted),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

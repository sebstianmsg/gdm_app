import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_radius.dart';
import '../../widgets/category_chip.dart';
import 'category_icons.dart';

/// Resultado del editor: los tres valores elegidos por el usuario.
class CategoryDraft {
  const CategoryDraft({required this.name, required this.color, required this.icon});
  final String name;
  final String color;
  final String icon;
}

/// Abre el editor de categoría (ícono + color + nombre) como bottom sheet.
/// Devuelve un [CategoryDraft] al guardar, o `null` si se cierra sin guardar.
///
/// [palette] es la lista de colores; [usedColors] (en mayúsculas) son los
/// colores ya ocupados por otras categorías, que se ocultan salvo el propio.
Future<CategoryDraft?> showCategoryEditor(
  BuildContext context, {
  required String title,
  required String saveLabel,
  required String initialName,
  required String initialColor,
  required String initialIcon,
  required List<String> palette,
  required Set<String> usedColors,
}) {
  return showModalBottomSheet<CategoryDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
    ),
    builder: (context) => _CategoryEditorBody(
      title: title,
      saveLabel: saveLabel,
      initialName: initialName,
      initialColor: initialColor,
      initialIcon: initialIcon,
      palette: palette,
      usedColors: usedColors,
    ),
  );
}

class _CategoryEditorBody extends StatefulWidget {
  const _CategoryEditorBody({
    required this.title,
    required this.saveLabel,
    required this.initialName,
    required this.initialColor,
    required this.initialIcon,
    required this.palette,
    required this.usedColors,
  });

  final String title;
  final String saveLabel;
  final String initialName;
  final String initialColor;
  final String initialIcon;
  final List<String> palette;
  final Set<String> usedColors;

  @override
  State<_CategoryEditorBody> createState() => _CategoryEditorBodyState();
}

class _CategoryEditorBodyState extends State<_CategoryEditorBody> {
  late final TextEditingController _nameController;
  late String _color;
  late String _icon;
  String? _error;

  /// `true` cuando el ícono fue elegido a mano (en "Símbolos") o venía ya
  /// asignado en la categoría. Mientras sea `false`, el nombre sugiere el ícono.
  late bool _iconIsManual;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _color = widget.initialColor;
    _icon = widget.initialIcon;
    // El ícono `help` se considera "sin elegir": habilita la sugerencia por
    // nombre. Cualquier otro valor inicial es un ícono ya asignado (manual).
    _iconIsManual = widget.initialIcon != 'help';
    _nameController.addListener(_onNameChanged);
    _applySuggestionFromName();
  }

  /// Si el usuario no eligió ícono a mano, preselecciona el sugerido por el
  /// nombre actual (o vuelve a `help` si el nombre dejó de matchear).
  void _applySuggestionFromName() {
    if (_iconIsManual) return;
    final suggested = suggestIconForName(_nameController.text) ?? 'help';
    if (suggested != _icon) {
      setState(() => _icon = suggested);
    }
  }

  void _onNameChanged() => _applySuggestionFromName();

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ingresá un nombre para la categoría.');
      return;
    }
    Navigator.pop(
      context,
      CategoryDraft(name: name, color: _color, icon: _icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              // Preview: círculo grande con color + ícono elegidos.
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: colorFromHex(_color), shape: BoxShape.circle),
                  child: Icon(iconForKey(_icon), color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Nombre de la categoría'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: context.palette.alert)),
              ],
              const SizedBox(height: 20),
              const Text('Símbolos', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _SymbolsCarousel(
                selected: _icon,
                selectedColor: colorFromHex(_color),
                onSelected: (key) => setState(() {
                  // Elegir en "Símbolos" fija el ícono a mano: la sugerencia por
                  // nombre deja de pisarlo (el manual siempre gana).
                  _icon = key;
                  _iconIsManual = true;
                }),
              ),
              const SizedBox(height: 20),
              const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _ColorSwatches(
                selected: _color,
                palette: widget.palette,
                usedColors: widget.usedColors,
                onSelected: (hex) => setState(() => _color = hex),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _save, child: Text(widget.saveLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carrusel paginado de símbolos: 8 por página (grid 4×2), swipe horizontal
/// e indicadores de punto. Con 56 íconos → 7 páginas.
class _SymbolsCarousel extends StatefulWidget {
  const _SymbolsCarousel({
    required this.selected,
    required this.selectedColor,
    required this.onSelected,
  });

  final String selected;
  final Color selectedColor;
  final ValueChanged<String> onSelected;

  @override
  State<_SymbolsCarousel> createState() => _SymbolsCarouselState();
}

class _SymbolsCarouselState extends State<_SymbolsCarousel> {
  static const _perPage = 8;
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // Abrir en la página del ícono seleccionado.
    // 'help' es el ícono por defecto (última entrada); en ese caso abrimos
    // en la primera página para que el listado empiece de izquierda a derecha.
    final keys = kCategoryIcons.keys.toList();
    final idx = widget.selected == 'help' ? -1 : keys.indexOf(widget.selected);
    _page = idx < 0 ? 0 : idx ~/ _perPage;
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = kCategoryIcons.entries.toList();
    final pageCount = (entries.length + _perPage - 1) ~/ _perPage;

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            itemCount: pageCount,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, page) {
              final start = page * _perPage;
              final end = (start + _perPage).clamp(0, entries.length);
              final pageEntries = entries.sublist(start, end);
              return GridView(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisExtent: 64,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                ),
                children: pageEntries.map((e) {
                  final isSel = e.key == widget.selected;
                  return Center(
                    child: GestureDetector(
                      onTap: () => widget.onSelected(e.key),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isSel
                              ? widget.selectedColor
                              : context.palette.textMuted.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(e.value,
                            color: isSel ? Colors.white : context.palette.textMuted, size: 24),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pageCount, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? widget.selectedColor
                    : context.palette.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Swatches de color con la regla de no-repetir del spec 02: se ocultan los
/// colores ya usados por otras categorías; el color propio siempre queda visible
/// y marcado con un tilde/anillo.
class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({
    required this.selected,
    required this.palette,
    required this.usedColors,
    required this.onSelected,
  });

  final String selected;
  final List<String> palette;

  /// Colores usados por OTRAS categorías (en mayúsculas). No incluye el propio.
  final Set<String> usedColors;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedUpper = selected.toUpperCase();

    // Libres (no usados por otras) + el color actual, que siempre se ve.
    final swatches = palette
        .where((hex) => hex.toUpperCase() == selectedUpper || !usedColors.contains(hex.toUpperCase()))
        .toList();
    // Si el color propio no está en la paleta (sembrado con otro hex), se agrega.
    if (selected.isNotEmpty && !swatches.any((hex) => hex.toUpperCase() == selectedUpper)) {
      swatches.insert(0, selected);
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: swatches.map((hex) {
        final isSel = hex.toUpperCase() == selectedUpper;
        return GestureDetector(
          onTap: () => onSelected(hex),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorFromHex(hex),
              shape: BoxShape.circle,
              border: isSel ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: isSel
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import 'category_summary.dart';
import 'donut_painter.dart';
import 'legend_list.dart';

// Violeta claro para el texto "Más detalles" en modo oscuro.
// Tinte claro del acento morado (ink #64009D), legible sobre el
// fondo oscuro de la card (#1F0A30).
const Color _masDetallesDarkText = Color(0xFFC6A3E8);

// Color del texto según el tema: negro en claro, violeta claro en oscuro.
Color _masDetallesColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? _masDetallesDarkText
        : const Color(0xFF000000); // negro

/// Tarjeta "Por categoría": donut (SVG-equivalente vía CustomPainter) con
/// botón "+" central que abre el alta de gasto, y debajo la leyenda.
/// Réplica de `.donut-card` / `#catSummary` en `public/index.html`.
class DonutCard extends StatelessWidget {
  const DonutCard({
    super.key,
    required this.summaries,
    required this.onAddPressed,
    required this.onManageCategories,
  });

  final List<CategorySummary> summaries;
  final VoidCallback onAddPressed;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'POR CATEGORÍA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.palette.textMuted,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.edit, color: context.palette.textMuted),
                onPressed: onManageCategories,
                tooltip: 'Agregar/Modificar categoría',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              // Lado del donut = ancho interno de la tarjeta − 8px de respiro
              // a cada lado (16px total), para que nunca toque el borde.
              final side = constraints.maxWidth - 16;
              return Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(side, side),
                        painter: DonutPainter(summaries: summaries),
                      ),
                      _AddButton(onPressed: onAddPressed),
                    ],
                  ),
                ),
              );
            },
          ),
          if (summaries.isNotEmpty) ...[
            const SizedBox(height: 24),
            _MoreDetailsButton(
              onPressed: () => _showLegendSheet(context, summaries),
            ),
          ],
        ],
      ),
    );
  }
}

// Abre un modal bottom sheet con el título "Por categoría" y la LegendList.
void _showLegendSheet(BuildContext context, List<CategorySummary> summaries) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.surface,
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'POR CATEGORÍA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.palette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              LegendList(summaries: summaries),
            ],
          ),
        ),
      );
    },
  );
}

class _MoreDetailsButton extends StatelessWidget {
  const _MoreDetailsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          'Más detalles',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _masDetallesColor(context),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.ink,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: context.palette.ink,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 96,
          height: 96,
          child: Icon(Icons.add, color: context.palette.inkText, size: 40),
        ),
      ),
    );
  }
}

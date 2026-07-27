import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'category_summary.dart';
import 'donut_painter.dart';
import 'legend_list.dart';

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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'POR CATEGORÍA',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.textMuted),
                onPressed: onManageCategories,
                tooltip: 'Agregar/Modificar categoría',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(240, 240),
                    painter: DonutPainter(summaries: summaries),
                  ),
                  _AddButton(onPressed: onAddPressed),
                ],
              ),
            ),
          ),
          if (summaries.isNotEmpty) ...[
            const SizedBox(height: 24),
            LegendList(summaries: summaries),
          ],
        ],
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
      color: AppColors.ink,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: AppColors.ink,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 96,
          height: 96,
          child: Icon(Icons.add, color: AppColors.inkText, size: 40),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'category_summary.dart';

Color _colorFromHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

/// Grid de leyenda: punto de color + nombre + monto + barra de progreso,
/// mismo orden que el donut (mayor a menor monto). Réplica de `#legendGrid`.
class LegendList extends StatelessWidget {
  const LegendList({super.key, required this.summaries});

  final List<CategorySummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: summaries.map((s) {
        final color = _colorFromHex(s.category.color);
        return SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.category.name,
                      style: AppTextStyles.description,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(formatMoney(s.amount), style: AppTextStyles.amount),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Container(height: 6, color: AppColors.surface2),
                      Container(
                        height: 6,
                        width: constraints.maxWidth * (s.percentage / 100),
                        color: color,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

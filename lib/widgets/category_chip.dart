import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/app_radius.dart';

Color colorFromHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

/// Pill de categoría: fondo = color + alfa 1a, texto/borde = color sólido.
/// Réplica del chip en `.entry` de `public/js/app.js`.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(category.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color),
      ),
      child: Text(
        category.name,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

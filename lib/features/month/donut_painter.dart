import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../categories/category_icons.dart';
import 'category_summary.dart';

Color _colorFromHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

/// Réplica del donut SVG dibujado a mano en `public/js/app.js`
/// (`buildArc`/`polarToXY`): viewBox 400x400, radio exterior 160, arranca en
/// -90° (12 en punto) y avanza en sentido horario, slices ordenados de mayor
/// a menor monto, con el hueco central tapado por el botón "+".
class DonutPainter extends CustomPainter {
  DonutPainter({required this.summaries});

  final List<CategorySummary> summaries;

  static const _viewBox = 400.0;
  static const _outerRadius = 196.0;
  static const _innerRadius = 74.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox;
    final center = Offset(size.width / 2, size.height / 2);
    final ringThickness = (_outerRadius - _innerRadius) * scale;
    final ringRadius = ((_outerRadius + _innerRadius) / 2) * scale;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);

    if (summaries.isEmpty) {
      final placeholder = Paint()
        ..color = const Color(0xFF26262E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness;
      canvas.drawArc(rect, 0, 2 * math.pi, false, placeholder);
      return;
    }

    // Paso 1 (SPEC 30): sombra proyectada del anillo. Un arco completo del mismo
    // grosor, oscuro y semitransparente, desplazado unos px hacia abajo y con blur,
    // para que el aro parezca despegado de la tarjeta. Queda tapado por los slices
    // dejando ver solo el halo inferior. Mismos parámetros en tema claro y oscuro.
    final shadowRect = rect.shift(Offset(0, 6 * scale));
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * scale);
    canvas.drawArc(shadowRect, 0, 2 * math.pi, false, shadowPaint);

    // Paso 2 (SPEC 30): bisel/gradiente en el grosor del anillo. Un RadialGradient
    // centrado en el donut, con el color base oscurecido hacia el radio interior y
    // aclarado hacia el exterior, da sensación tubular/abombada. Los `stops` mapean
    // el rango [innerRadius, outerRadius] del anillo. Mismos parámetros claro/oscuro.
    final innerR = _innerRadius * scale;
    final outerR = _outerRadius * scale;
    final gradientRect = Rect.fromCircle(center: center, radius: outerR);
    final innerStop = innerR / outerR;

    var startAngle = -math.pi / 2;
    for (final s in summaries) {
      final sweep = (s.percentage / 100) * 2 * math.pi;
      final base = HSLColor.fromColor(
        _colorFromHex(displayCategoryColor(s.category)),
      );
      final dark = base
          .withLightness((base.lightness - 0.14).clamp(0.0, 1.0))
          .toColor();
      final light = base
          .withLightness((base.lightness + 0.14).clamp(0.0, 1.0))
          .toColor();
      final gradient = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [dark, base.toColor(), light],
        stops: [innerStop, (innerStop + 1) / 2, 1.0],
      );
      final paint = Paint()
        ..shader = gradient.createShader(gradientRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness;
      // Pequeño gap entre slices, como el prototipo (evita que se vean pegados).
      final gap = summaries.length > 1 ? 0.014 : 0.0;
      canvas.drawArc(
        rect,
        startAngle + gap / 2,
        math.max(sweep - gap, 0),
        false,
        paint,
      );

      if (s.percentage >= 5) {
        final midAngle = startAngle + sweep / 2;
        final labelPos = Offset(
          center.dx + ringRadius * math.cos(midAngle),
          center.dy + ringRadius * math.sin(midAngle),
        );
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${s.percentage.round()}%',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              // Paso 3 (SPEC 30): sombra leve para despegar los `%` del relieve,
              // sin cambiar color (blanco), tamaño (20) ni posición.
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) =>
      oldDelegate.summaries != summaries;
}

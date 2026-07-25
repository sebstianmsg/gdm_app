import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  static const _outerRadius = 160.0;
  static const _innerRadius = 72.0;

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

    var startAngle = -math.pi / 2;
    for (final s in summaries) {
      final sweep = (s.percentage / 100) * 2 * math.pi;
      final paint = Paint()
        ..color = _colorFromHex(s.category.color)
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
              fontSize: 15 * scale * 2.2,
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

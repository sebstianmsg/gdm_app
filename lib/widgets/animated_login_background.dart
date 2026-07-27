import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo animado propio del login: una burbuja clara que se desplaza de forma
/// orgánica y continua (patrón tipo Lissajous) sobre un fondo morado casi
/// negro. Dibuja el [child] encima del fondo mediante un `Stack`.
class AnimatedLoginBackground extends StatefulWidget {
  const AnimatedLoginBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedLoginBackground> createState() =>
      _AnimatedLoginBackgroundState();
}

class _AnimatedLoginBackgroundState extends State<AnimatedLoginBackground>
    with SingleTickerProviderStateMixin {
  // Fondo base (hardcodeado en el widget, no vía AppColors).
  static const Color _bgColor = Color(0xFF0B0610);
  static const Color _bubbleColor = Color(0xFF2E1147);

  // Animación: loop continuo, sin reverse.
  static const Duration _cycle = Duration(seconds: 18);

  // Burbuja: diámetro en px.
  static const double _bubbleSize = 560;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Trayectoria Lissajous: t = value * 2 * pi.
                  final t = _controller.value * 2 * math.pi;
                  final dx = width * (0.50 + math.sin(t) * 0.28);
                  final dy = height * (0.45 + math.cos(t * 2) * 0.22);
                  return Positioned(
                    left: dx - _bubbleSize / 2,
                    top: dy - _bubbleSize / 2,
                    child: Container(
                      width: _bubbleSize,
                      height: _bubbleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          stops: const [0.0, 0.45, 1.0],
                          colors: [
                            _bubbleColor.withValues(alpha: 1.0),
                            _bubbleColor.withValues(alpha: 0.55),
                            _bubbleColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              widget.child,
            ],
          );
        },
      ),
    );
  }
}

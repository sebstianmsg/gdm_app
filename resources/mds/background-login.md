# Background animado - Pantalla de Login

## Objetivo
Implementar el fondo de la pantalla de login con un difuminado en tonos morados donde una burbuja de color claro se mueve por la pantalla de forma suave, orgánica y continua (sin efecto de "rebote" ida y vuelta).

## Colores
- Fondo base: `#0B0610`
- Color de la burbuja (gradiente radial): `#180826`

## Comportamiento esperado
- Loop infinito y continuo (`AnimationController.repeat()`, sin `reverse: true`).
- Movimiento orgánico usando combinación de funciones seno/coseno con distinta frecuencia y fase (patrón tipo Lissajous), no un rebote lineal entre dos puntos.
- Duración del ciclo: ~18 segundos (ajustable).
- Debe verse detrás del formulario de login sin interferir con la interacción táctil (usar `Stack` con el form encima).

## Implementación de referencia (Flutter)

```dart
import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedLoginBackground extends StatefulWidget {
  final Widget child;
  const AnimatedLoginBackground({super.key, required this.child});

  @override
  State<AnimatedLoginBackground> createState() => _AnimatedLoginBackgroundState();
}

class _AnimatedLoginBackgroundState extends State<AnimatedLoginBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0610),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final size = MediaQuery.of(context).size;
              final t = _controller.value * 2 * pi;

              final dx = size.width * 0.5 + sin(t) * size.width * 0.28;
              final dy = size.height * 0.45 + cos(t * 0.7) * size.height * 0.22;

              return Positioned(
                left: dx - 180,
                top: dy - 180,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF180826).withOpacity(0.9),
                        const Color(0xFF180826).withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}
```

## Uso
Envolver la pantalla de login existente:

```dart
AnimatedLoginBackground(
  child: LoginForm(), // widget actual del formulario
)
```

## Tareas para Claude Code
1. Crear el widget `AnimatedLoginBackground` (archivo sugerido: `lib/widgets/animated_login_background.dart`).
2. Envolver la pantalla de login actual con este widget, sin modificar la lógica del formulario.
3. Verificar que el `AnimationController` se disponga correctamente (`dispose()`) para evitar leaks.
4. Ajustar tamaño/opacidad de la burbuja si al probar en dispositivo se ve muy tenue o muy intensa contra el fondo `#0B0610`.
5. Confirmar que la animación no cause jank (probar en modo release/profile).

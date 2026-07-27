# SPEC 06 — Background animado en la pantalla de login

> **Estado:** Implementado
> **Dependencias:** SPEC 03 (paleta morada / estructura de theme)
> **Fecha:** 2026-07-27
> **Objetivo:** Agregar un fondo animado propio del login —una burbuja clara que se desplaza de forma orgánica y continua (patrón tipo Lissajous) sobre un fondo morado casi negro— detrás del formulario, sin modificar la lógica de autenticación.

---

## Alcance

**Dentro:**

1. **Nuevo widget `AnimatedLoginBackground`** en `lib/widgets/animated_login_background.dart`.
   - `StatefulWidget` con `SingleTickerProviderStateMixin`.
   - Recibe un `child` (el contenido del login) y lo dibuja encima del fondo con un `Stack`.
   - Fondo base color `#0B0610` (hardcodeado en el widget, no vía `AppColors`).
   - Una burbuja circular de 560×560 con `RadialGradient` en tonos `#2E1147` (1.0 → 0.55 → transparente, stops 0.0 / 0.45 / 1.0).
   - Movimiento orgánico con `AnimationController.repeat()` (sin `reverse`), combinando `sin(t)` y `cos(t * 2)` para un patrón tipo Lissajous que cierra sobre sí mismo sin salto. Ciclo de ~18 s.
   - `dispose()` del `AnimationController` para evitar leaks.

2. **Integración en `login_screen.dart`.**
   - Envolver el contenido del `body` (el `Center(...)`) con `AnimatedLoginBackground`.
   - Cambiar `Scaffold.backgroundColor` de `AppColors.bg` a `Colors.transparent` (o quitarlo) para que se vea el fondo animado.
   - No se toca la lógica del formulario ni `authProvider`.

**Fuera de alcance (para futuros specs):**

- Respetar "reducir movimiento" del sistema (`MediaQuery.disableAnimations`) — se hará en un spec posterior.
- Aplicar este background en otras pantallas (home, modales).
- Parametrizar colores/tamaño/duración de la burbuja vía tokens de `AppColors` o config.
- Múltiples burbujas, blur (`ImageFilter`) o efectos de partículas.
- Tests de widget para la animación.

---

## Modelo de datos

_Esta feature no introduce estructuras de datos persistentes ni estado compartido._ Solo un `AnimationController` interno al widget y un conjunto de constantes de dibujo, que se dejan documentadas como referencia:

```dart
// Fondo base (hardcodeado en el widget, no vía AppColors)
static const Color _bgColor     = Color(0xFF0B0610);
static const Color _bubbleColor = Color(0xFF2E1147);

// Animación
static const Duration _cycle = Duration(seconds: 18); // loop continuo, sin reverse

// Burbuja
static const double _bubbleSize = 560; // diámetro en px

// Trayectoria Lissajous (fracciones del tamaño de pantalla)
// centro X: 0.50 + sin(t)     * 0.28
// centro Y: 0.45 + cos(t * 2) * 0.22   // frecuencia entera → cierra sin salto
// donde t = controller.value * 2 * pi

// Gradiente radial de la burbuja: opacidades 1.0 → 0.55 → transparente (stops 0.0 / 0.45 / 1.0)
```

Convenciones:

- Origen de coordenadas: esquina superior izquierda.
- `left = dx - _bubbleSize/2`, `top = dy - _bubbleSize/2` para centrar la burbuja en `(dx, dy)`.

---

## Plan de implementación

1. **Crear el esqueleto del widget.** Nuevo archivo `lib/widgets/animated_login_background.dart` con `AnimatedLoginBackground extends StatefulWidget`, campo `final Widget child`, y su `State` con `SingleTickerProviderStateMixin`. `build` devuelve por ahora un `Container(color: _bgColor, child: child)`. *Test manual:* importarlo temporalmente compila (`flutter analyze` limpio).

2. **Agregar el `AnimationController` y su ciclo de vida.** En `initState` crear el controller con `duration: _cycle` y `..repeat()`; en `dispose()` llamar `_controller.dispose()`. Definir las constantes de dibujo del modelo de datos. *Test manual:* `flutter analyze` limpio, sin warnings de recursos sin liberar.

3. **Dibujar el fondo y la burbuja animada.** En `build`, usar `Container(color: _bgColor)` envolviendo un `LayoutBuilder` + `Stack` con: (a) un `AnimatedBuilder(animation: _controller)` que calcula `dx`/`dy` con la trayectoria Lissajous y posiciona la burbuja (`Positioned` + `Container` circular con `RadialGradient` de `_bubbleColor`), y (b) `widget.child` encima. *Test manual:* montar el widget con un `child` cualquiera y ver la burbuja moverse de forma continua sin rebote ni salto al reiniciar el loop.

4. **Integrar en `login_screen.dart`.** Envolver el `Center(...)` del `body` con `AnimatedLoginBackground(child: ...)` y cambiar `Scaffold.backgroundColor` a `Colors.transparent`. No tocar controllers, `_submit` ni `authProvider`. *Test manual:* correr la app, ver el fondo morado casi negro con la burbuja detrás del formulario; los inputs y el botón siguen respondiendo al tacto.

5. **Verificación integral.** `flutter analyze` limpio y `flutter test` verde. Revisión visual: la burbuja no queda demasiado tenue ni demasiado intensa contra `#0B0610` (ajustar opacidad/tamaño si hace falta) y no hay jank evidente. *Test manual:* recorrer login → autenticación exitosa → home.

---

## Criterios de aceptación

- [ ] Existe el archivo `lib/widgets/animated_login_background.dart` con el widget `AnimatedLoginBackground` (`StatefulWidget` con `SingleTickerProviderStateMixin`).
- [ ] El widget recibe un `child` y lo dibuja **encima** del fondo mediante un `Stack`.
- [ ] El fondo base es color `#0B0610` hardcodeado en el widget (no vía `AppColors`).
- [ ] Hay una burbuja circular de 560×560 con `RadialGradient` en tonos `#2E1147` (opacidades 1.0 → 0.55 → transparente, stops 0.0 / 0.45 / 1.0).
- [ ] La animación usa `AnimationController.repeat()` **sin** `reverse`, con ciclo de ~18 s.
- [ ] El movimiento es orgánico tipo Lissajous (`sin(t)` y `cos(t * 2)`), sin efecto de rebote lineal ida y vuelta y **sin salto** al reiniciar el loop (la curva cierra sobre sí misma).
- [ ] El `AnimationController` se libera en `dispose()`.
- [ ] En `login_screen.dart`, el contenido del `body` está envuelto por `AnimatedLoginBackground` y el `Scaffold.backgroundColor` es transparente.
- [ ] La lógica del formulario (`_submit`, controllers, `authProvider`) no cambió.
- [ ] Los campos de email/contraseña y el botón "Iniciar sesión" siguen respondiendo al tacto con el fondo detrás.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Colores del fondo del login | Colores exactos del md (`#0B0610` / `#180826`) hardcodeados en el widget | Mapear a tokens de `AppColors` de la paleta morada (SPEC 03) | Es un fondo decorativo propio del login, no parte del theme global; se mantiene fiel a la referencia visual del md. |
| Ubicación del archivo | `lib/widgets/animated_login_background.dart` | `lib/features/auth/` junto al `login_screen.dart` | Sigue la sugerencia del md y la convención existente (`lib/widgets/` ya aloja widgets reutilizables como `category_chip.dart`). |
| Integración con el Scaffold | Envolver el `body` con el widget y poner `backgroundColor: Colors.transparent` | Reemplazar el `Scaffold` o mover el fondo a un nivel superior | Cambio mínimo y contenido; no toca la lógica del formulario. |
| Tipo de animación | Loop continuo `repeat()` con patrón Lissajous (`sin`/`cos` con distinta frecuencia) | `reverse: true` (rebote ida y vuelta) | Movimiento orgánico pedido en el md; el rebote lineal se ve mecánico. |
| Frecuencia de la componente Y | `cos(t * 2)` (frecuencia entera) | `cos(t * 0.7)` (frecuencia fraccionaria del md original) | Con `0.7` la curva no completaba un número entero de ciclos por vuelta del controller, así que Y no cerraba en su punto de origen y se veía un salto visible al reiniciar el loop (~18 s). Con un factor entero (`2`) la trayectoria cierra sobre sí misma y el loop empalma sin corte, conservando el look Lissajous orgánico. |
| Tamaño e intensidad de la burbuja | 560×560, color `#2E1147`, opacidades 1.0 → 0.55 → transparente | 360×360, `#180826`, 0.9 → 0.15 → transparente (valores originales del md) | En la verificación visual (paso 5) el glow original apenas se percibía contra `#0B0610`; se agrandó y aclaró para que el efecto sea notorio, según la referencia visual aprobada. |
| Reducir movimiento (accesibilidad) | Fuera de alcance en este spec | Implementarlo ahora vía `MediaQuery.disableAnimations` | El usuario lo difirió explícitamente a un spec posterior para mantener este contenido. |
| Cantidad de burbujas / blur | Una sola burbuja con `RadialGradient` | Varias burbujas o `ImageFilter.blur` | Suficiente para el efecto buscado; más elementos agregan costo de render sin pedido. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| La burbuja se ve demasiado tenue o demasiado intensa contra `#0B0610` | Fondo poco perceptible o distractor | Ajustar opacidades del `RadialGradient` y/o `_bubbleSize` en la verificación visual (paso 5). |
| Jank / caídas de FPS por repintar la burbuja cada frame | Animación con tirones en dispositivos de gama baja | El `AnimatedBuilder` solo reconstruye la burbuja, no el `child`; probar en modo profile/release y reducir tamaño si hace falta. |
| Animación infinita corriendo mientras el login está en pantalla | Consumo de batería/CPU | Contenido a un solo login efímero; el controller se libera en `dispose()` al salir de la pantalla. |
| Sin respetar "reducir movimiento" (fuera de alcance) | Usuarios sensibles al movimiento ven la animación igual | Aceptado conscientemente; se aborda en un spec posterior (registrado en Decisiones). |

---

## Lo que **no** entra en este spec

- Respetar "reducir movimiento" del sistema (spec posterior).
- Aplicar el background en otras pantallas (home, modales).
- Parametrizar colores/tamaño/duración vía `AppColors` o config.
- Múltiples burbujas, blur o partículas.
- Tests de widget para la animación.

Cada uno, si se implementa, va en su propio spec.

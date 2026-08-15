# SPEC 24 — Fondo animado del login adaptado al tema (colores más claros + variante gris)

> **Estado:** Implementado
> **Dependencias:** SPEC 06 (fondo animado del login `AnimatedLoginBackground`), SPEC 11 (theming dual claro/oscuro, `AppTheme`/`AppPalette`)
> **Fecha:** 2026-08-15
> **Objetivo (una frase):** Hacer que el fondo animado del login reaccione al tema activo, aclarando los tonos morados del modo oscuro para que la burbuja se aprecie mejor y agregando una variante en grises para el modo claro (fondo gris claro con burbuja gris más oscura), sin tocar el movimiento, tamaño ni gradiente de la animación.

---

## Alcance

**Dentro:**

1. **Hacer `AnimatedLoginBackground` sensible al tema.** Dentro del widget, resolver la brillantez activa con `Theme.of(context).brightness` y elegir el par de colores (fondo + burbuja) según sea oscuro o claro. La detección ocurre en `build`, por lo que cambia solo con el tema activo, sin tocar `login_screen.dart`.

2. **Aclarar los colores del modo oscuro.** Reemplazar los actuales por morados más vivos:
   - Fondo base: `#0B0610` → `#1A0B2E`.
   - Burbuja: `#2E1147` → `#4A1D73`.

3. **Agregar la variante gris para el modo claro** (mancha oscura sobre gris claro):
   - Fondo base: gris claro (hex concreto en la sección Modelo de datos).
   - Burbuja: gris más oscuro que el fondo, con el mismo `RadialGradient` (opacidades 1.0 → 0.55 → transparente, stops 0.0 / 0.45 / 1.0).

**Fuera de alcance:**

- Cualquier cambio en la animación: trayectoria Lissajous, ciclo de ~18 s, tamaño de burbuja (560), forma del gradiente radial y stops **quedan idénticos**.
- Cambios en `login_screen.dart` (integración, `Scaffold`, lógica del formulario).
- Parametrizar los colores del fondo vía `AppColors`/`AppPalette` o tokens de tema (siguen hardcodeados dentro del widget, como en el SPEC 06).
- Opción "reducir movimiento" / accesibilidad (sigue diferida).
- Aplicar el fondo en otras pantallas o agregar múltiples burbujas, blur o partículas.
- Transición animada al alternar el tema mientras el login está en pantalla (el cambio de par de colores es directo, sin cross-fade).

Nota: esto revierte deliberadamente la decisión del SPEC 11 ("fondo del login idéntico en ambos temas"), registrado en Decisiones.

---

## Modelo de datos

_Esta feature no introduce datos persistentes ni estado compartido._ Solo cambia el conjunto de constantes de color del widget, que pasa de un único par a **dos pares** seleccionados según `Theme.of(context).brightness`. Se documentan como referencia:

```dart
// --- Modo oscuro (aclarado respecto del SPEC 06) ---
static const Color _bgDark     = Color(0xFF1A0B2E); // antes #0B0610
static const Color _bubbleDark = Color(0xFF4A1D73); // antes #2E1147

// --- Modo claro (nueva variante en grises) ---
static const Color _bgLight     = Color(0xFFDAD5E3); // gris claro (ajustado en paso 4: un tono más oscuro)
static const Color _bubbleLight = Color(0xFFABA2BE); // gris más oscuro que el fondo (ajustado en paso 4)

// Sin cambios (idénticos al SPEC 06):
static const Duration _cycle = Duration(seconds: 18); // loop continuo, sin reverse
static const double _bubbleSize = 560;                // diámetro en px
// Gradiente radial: opacidades 1.0 → 0.55 → transparente, stops 0.0 / 0.45 / 1.0
// Trayectoria Lissajous: dx = w*(0.50 + sin(t)*0.28), dy = h*(0.45 + cos(2t)*0.22)
```

Selección en `build`:

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final bgColor     = isDark ? _bgDark     : _bgLight;
final bubbleColor = isDark ? _bubbleDark : _bubbleLight;
```

Los grises del modo claro llevan un leve tinte lila (`#DAD5E3` / `#ABA2BE`) para armonizar con la paleta clara del SPEC 11 (`surface #F5F2F8`) en lugar de un gris neutro puro.

Convenciones (sin cambios respecto del SPEC 06):

- Origen de coordenadas: esquina superior izquierda.
- `left = dx - _bubbleSize/2`, `top = dy - _bubbleSize/2` para centrar la burbuja en `(dx, dy)`.

---

## Plan de implementación

Cada paso deja el widget compilando y la app funcional.

1. **Duplicar las constantes de color en pares por tema.** En `animated_login_background.dart`, reemplazar `_bgColor`/`_bubbleColor` por los cuatro `const` nuevos (`_bgDark`, `_bubbleDark`, `_bgLight`, `_bubbleLight`) con los hex del Modelo de datos. Dejar `_cycle`, `_bubbleSize` y el gradiente sin tocar. *Verificación:* `flutter analyze` limpio.

2. **Resolver el par de colores según el tema en `build`.** Al inicio de `build`, calcular `isDark = Theme.of(context).brightness == Brightness.dark` y derivar `bgColor`/`bubbleColor`. Pasar `bgColor` al `Container` externo y `bubbleColor` al `RadialGradient` (en lugar de las constantes fijas). *Verificación:* `flutter analyze` limpio; la burbuja usa el color derivado.

3. **Verificar el modo oscuro aclarado.** Correr la app en tema oscuro y entrar al login: el fondo es morado (`#1A0B2E`) y la burbuja (`#4A1D73`) se aprecia claramente moviéndose, sin verse "negro dando vueltas". *Verificación manual:* el efecto es más notorio que antes; ajustar hex si quedara muy tenue o muy intenso.

4. **Verificar el modo claro en grises.** Con tema claro activo, entrar al login (o cerrar sesión desde modo claro): el fondo es gris claro (`#EDEBF0`) con una burbuja gris más oscura (`#C4BFCC`) desplazándose; ya no aparece el fondo oscuro detrás del login blanco. *Verificación manual:* la mancha gris se percibe pero no compite con el formulario.

5. **Verificar el cambio de tema en caliente.** Alternar el tema desde el menú de usuario (SPEC 11) y volver al login: el fondo cambia de par de colores acorde al tema activo. *Verificación manual:* oscuro → morado, claro → gris, sin errores.

6. **Verificación integral.** `flutter analyze` limpio y `flutter test` verde; el movimiento, tamaño y gradiente son idénticos a antes. *Verificación:* recorrido login → autenticación → home en ambos temas.

---

## Criterios de aceptación

- [ ] `AnimatedLoginBackground` define cuatro constantes de color: `_bgDark` `#1A0B2E`, `_bubbleDark` `#4A1D73`, `_bgLight` `#DAD5E3`, `_bubbleLight` `#ABA2BE` (hardcodeadas en el widget, no vía `AppColors`/`AppPalette`).
- [ ] En `build`, el widget resuelve el tema activo con `Theme.of(context).brightness` y elige el par fondo/burbuja acorde (oscuro → morados, claro → grises).
- [ ] En modo **oscuro**, el fondo es `#1A0B2E` y la burbuja `#4A1D73`; la burbuja se aprecia claramente (más notoria que con los colores previos `#0B0610`/`#2E1147`).
- [ ] En modo **claro**, el fondo es `#DAD5E3` y la burbuja `#ABA2BE` (mancha gris más oscura sobre gris claro); al cerrar sesión desde modo claro ya no aparece el fondo oscuro detrás del login blanco.
- [ ] Al alternar el tema desde el menú de usuario y volver al login, el fondo cambia de par de colores según el tema activo.
- [ ] La animación no cambió: trayectoria Lissajous (`sin(t)` / `cos(2t)`), ciclo de ~18 s con `repeat()` sin `reverse`, burbuja de 560×560 y `RadialGradient` con opacidades 1.0 → 0.55 → transparente y stops 0.0 / 0.45 / 1.0.
- [ ] No se modificó `login_screen.dart` (integración, `Scaffold.backgroundColor` transparente y lógica del formulario intactos).
- [ ] El `AnimationController` sigue liberándose en `dispose()`.
- [ ] `flutter analyze` no reporta errores y `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Detección del tema | Leer `Theme.of(context).brightness` dentro del widget en `build` | Pasar el tema/colores por parámetro desde `login_screen.dart`; leer `AppPalette` | Cero cambios en el login; el widget reacciona solo al tema activo, manteniéndose autocontenido como en el SPEC 06. |
| Colores del modo oscuro | Aclararlos a `#1A0B2E` / `#4A1D73` | Mantener `#0B0610` / `#2E1147` | Los originales se veían casi negros ("algo negro dando vueltas"); subir el tono hace visible la burbuja. |
| Enfoque de la variante clara | Fondo gris claro con burbuja gris **más oscura** (mancha oscura sobre claro) | Fondo gris oscuro con burbuja clara (mismo patrón que el oscuro) | Sobre un login blanco, una burbuja más oscura se aprecia sin chocar con el formulario ni recrear el "fondo oscuro" que se veía raro. |
| Tinte de los grises | Grises con leve tinte lila (`#EDEBF0` / `#C4BFCC`) | Gris neutro puro | Armoniza con la paleta clara del SPEC 11 (`surface #F5F2F8`) y conserva identidad de marca. |
| Colores del fondo | Hardcodeados en el widget (cuatro `const`) | Mapear a tokens de `AppColors`/`AppPalette` | Es un fondo decorativo propio del login, no parte del theme global; se mantiene la convención del SPEC 06. |
| Fondo del login por tema | **Variante distinta** por tema (revierte el SPEC 11) | Mantener el fondo idéntico en ambos temas (decisión del SPEC 11) | El usuario notó que en modo claro el fondo oscuro tras el login blanco quedaba raro; se decide diferenciarlo. |
| Animación | Intacta (movimiento, tamaño, gradiente) | Ajustar también trayectoria/tamaño/opacidad | El usuario pidió explícitamente no tocar nada de la animación; solo cambian los colores. |
| Transición al alternar tema | Cambio directo de par de colores | Cross-fade animado entre temas | El login rara vez está visible durante el toggle; el cross-fade agrega complejidad sin pedido. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| La burbuja gris del modo claro contrasta poco contra el fondo gris claro y casi no se aprecia. | El efecto se pierde en claro (mismo problema que hoy tiene el oscuro). | Verificación visual dedicada (paso 4); ajustar `_bubbleLight` a un gris más oscuro o `_bgLight` más claro si hace falta. |
| Los morados aclarados del modo oscuro reducen el contraste del formulario del login sobre el fondo. | Inputs/botón menos legibles en oscuro. | Revisar en el paso 3 que el formulario siga legible; si molesta, bajar levemente el tono del fondo `#1A0B2E`. |
| La burbuja gris más oscura del modo claro compite visualmente con el formulario blanco y distrae. | Fondo distractor en claro. | Ajustar opacidad efectiva vía el hex de `_bubbleLight` (más claro) en la verificación del paso 4. |
| Regenerar/editar el widget deja alguna referencia al color viejo (`_bgColor`/`_bubbleColor`). | `flutter analyze` con error o color incorrecto. | Reemplazar por completo las constantes y compilar; `flutter analyze` debe quedar limpio. |

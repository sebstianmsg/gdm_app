# SPEC 17 — "Más detalles": leyenda de gastos en ventana aparte

> **Estado:** Approved
> **Dependencias:** spec 04 (`DonutCard`, donut grande/responsive), spec 11 (`AppPalette`/`context.palette`, tema claro/oscuro), spec 14 (`DonutCard` vive dentro de `HomeCarousel` como card 1), spec 15 (`displayCategoryColor` usado por `LegendList`)
> **Fecha:** 2026-08-10
> **Objetivo (una frase):** Sacar la leyenda de categorías de debajo del donut y mostrarla en un **modal bottom sheet** que se abre con un botón de texto "Más detalles" —visible solo cuando hay gastos— ubicado debajo del donut.

---

## Alcance

**Incluye:**

1. **Quitar la leyenda inline** de `DonutCard` (el bloque `if (summaries.isNotEmpty) LegendList` debajo del donut).

2. **Botón de texto "Más detalles"** debajo del donut, dentro de `DonutCard`:
   - Solo se renderiza cuando hay gastos (`summaries.isNotEmpty`); sin gastos no se muestra.
   - Botón de solo texto, centrado, texto literal "Más detalles".
   - Color del texto: **negro** en modo claro y **violeta claro** en modo oscuro.

3. **Modal bottom sheet** al tocar "Más detalles":
   - Título **"Por categoría"** arriba (mismo estilo de encabezado que usa `DonutCard`: mayúsculas, `w700`, `textMuted`).
   - Debajo, la misma `LegendList` que hoy aparece inline.
   - `showModalBottomSheet`; se cierra deslizando o tocando afuera.

**No incluye:**

- **Estado vacío / estilo apagado del botón** (se descarta lo del color "gris claro / violeta apagado" sin gastos, porque el botón no se muestra sin gastos).
- **Cambiar el contenido de `LegendList`** (se reutiliza tal cual).
- **Tocar** el donut, el botón "+", el total del mes, la MovementsCard ni el resto del carrusel.
- **Acciones nuevas dentro del modal** más allá del título + la leyenda.

---

## Modelo de datos

Este spec **no introduce datos persistidos nuevos** ni modifica el esquema: es solo una reorganización de UI. Reutiliza `CategorySummary` y `LegendList` de spec 04/15 sin cambios.

La única "estructura" nueva es una **constante de color** para el texto del botón "Más detalles" en modo oscuro (violeta claro). En modo claro el texto es negro; se puede resolver con la paleta existente, pero el violeta claro del modo oscuro no existe hoy como token.

Ubicación: junto al widget del botón, en `donut_card.dart`.

```dart
// Violeta claro para el texto "Más detalles" en modo oscuro.
// Tinte claro del acento morado (ink #64009D), legible sobre el
// fondo oscuro de la card (#1F0A30).
const Color _masDetallesDarkText = Color(0xFFC6A3E8);

// Color del texto según el tema: negro en claro, violeta claro en oscuro.
Color _masDetallesColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? _masDetallesDarkText
        : const Color(0xFF000000); // negro
```

Notas:
- El negro del modo claro se deja en `#000000` (negro puro, como se pidió), no en `palette.text` (`#1A1024`, casi negro), para respetar el pedido literal.
- El violeta claro `#C6A3E8` es un tinte del acento `ink`; queda por encima de `bg`/`card` del modo oscuro con buen contraste.

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Constante y helper de color** en `donut_card.dart`: agregar `_masDetallesDarkText = Color(0xFFC6A3E8)` y `_masDetallesColor(BuildContext)` (negro en claro, violeta claro en oscuro). *Verificación:* `flutter analyze` limpio; el helper devuelve `#000000` en tema claro y `#C6A3E8` en oscuro.

2. **Widget del botón "Más detalles"** (`_MoreDetailsButton`, privado en `donut_card.dart`): botón de solo texto centrado (`TextButton` o `InkWell` + `Text`), texto literal "Más detalles", color vía `_masDetallesColor(context)`, que recibe un `VoidCallback onPressed`. *Verificación:* `flutter analyze` limpio; el botón se ve centrado y con el color correcto en ambos temas.

3. **Modal bottom sheet** (`_showLegendSheet(BuildContext, List<CategorySummary>)`): abre `showModalBottomSheet` con fondo `context.palette.surface`, esquinas redondeadas, título "Por categoría" (estilo del encabezado de `DonutCard`: mayúsculas, `w700`, `textMuted`) y debajo la `LegendList` existente dentro de un contenido scrolleable. *Verificación manual:* al invocarlo se abre el sheet con el título y la leyenda completa; se cierra deslizando o tocando afuera.

4. **Reemplazar la leyenda inline por el botón** en `DonutCard.build`: cambiar el bloque `if (summaries.isNotEmpty) [SizedBox, LegendList]` por `if (summaries.isNotEmpty) [SizedBox, _MoreDetailsButton(onPressed: () => _showLegendSheet(context, summaries))]`. *Verificación manual:* con gastos aparece el botón (no la leyenda inline) y abre el modal; sin gastos no aparece nada debajo del donut.

5. **Repaso e integración.** `flutter analyze` limpio y `flutter test` en verde. Recorrido visual en tema claro y oscuro dentro del carrusel (card 1): botón visible solo con gastos, color correcto por tema, modal con título + leyenda, cierre correcto, y el resto del home (donut, "+", total, MovementsCard) intacto. *Verificación:* suite en verde y sin regresiones.

---

## Criterios de aceptación

- [ ] Cuando hay gastos (`summaries.isNotEmpty`), **debajo del donut** aparece un botón de solo texto con el texto literal "Más detalles", centrado.
- [ ] La leyenda (`LegendList`) **ya no** se muestra inline debajo del donut.
- [ ] Cuando **no hay gastos**, no se muestra ni el botón "Más detalles" ni la leyenda (no hay nada debajo del donut).
- [ ] El texto "Más detalles" se ve **negro** (`#000000`) en modo claro y **violeta claro** (`#C6A3E8`) en modo oscuro.
- [ ] Al tocar "Más detalles" se abre un **modal bottom sheet** con el título **"Por categoría"** arriba y debajo la misma `LegendList` (punto de color + nombre + monto + barra, en el mismo orden que hoy).
- [ ] El modal se cierra deslizando hacia abajo o tocando fuera.
- [ ] El donut, el botón "+", el "TOTAL DEL MES", la MovementsCard y el resto del carrusel quedan **intactos** (sin regresiones).
- [ ] `flutter analyze` no reporta errores y `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Dónde se muestra la leyenda | **Modal bottom sheet** aparte | Leyenda inline (como hoy) / diálogo centrado / pantalla nueva | El usuario quiere sacarla de debajo del donut; el bottom sheet es coherente con el resto de la app y no agrega navegación. |
| Botón sin gastos | **No se muestra** | Verse apagado (gris claro / violeta) pero no tocable | Decisión explícita del usuario; descarta la parte del pedido original sobre el color del texto en estado vacío. |
| Estilo del botón | **Solo texto** "Más detalles", centrado | Botón con fondo/borde/ícono | El pedido fue "un simple texto"; sin peso visual que compita con el donut. |
| Negro del modo claro | **`#000000` (negro puro)** | `palette.text` (`#1A1024`, casi negro) | Respeta el pedido literal de "color negro". |
| Violeta claro del modo oscuro | **`#C6A3E8`** (tinte de `ink`) | Reusar `palette.text` (blanco) / token existente | No hay token de violeta claro; se define uno coherente con la paleta morada y legible sobre la card oscura. |
| Título del modal | **"Por categoría"** arriba | Modal con solo la leyenda pelada | El usuario pidió el título; da contexto a la ventana. |
| Contenido del modal | **Reusar `LegendList` tal cual** | Reescribir la leyenda para el modal | Evita duplicar UI y mantiene un solo lugar de verdad para la leyenda. |

---

## Qué **no** está en este spec

- Estado vacío o estilo apagado del botón (el botón no se muestra sin gastos).
- Cambios al contenido de `LegendList`, al donut, al botón "+", al total del mes o a la MovementsCard.
- Acciones nuevas dentro del modal más allá del título + la leyenda.

Cada una de esas, si alguna vez se hace, va en su propio spec.

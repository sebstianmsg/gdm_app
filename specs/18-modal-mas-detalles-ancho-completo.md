# SPEC 18 — "Más detalles": el modal ocupa el ancho de la pantalla

> **Estado:** Implementado
> **Dependencias:** spec 17 (`_showLegendSheet` / botón "Más detalles" / `LegendList` en modal), spec 11 (`context.palette` para el fondo del sheet)
> **Fecha:** 2026-08-11
> **Objetivo (una frase):** Hacer que el modal bottom sheet de "Más detalles" (`_showLegendSheet` en `donut_card.dart`) llegue de borde a borde ocupando todo el ancho de la pantalla, en vez de aparecer centrado y angosto por el `maxWidth` por defecto de Material 3.

---

## Alcance

**Incluye:**

1. **Forzar el ancho completo del modal** `_showLegendSheet` (`donut_card.dart`): que el bottom sheet se extienda de borde a borde de la pantalla, sin el `maxWidth` centrado que aplica Material 3 por defecto. La forma concreta de lograrlo va en la sección de decisiones.

2. **Ajustar el contenido al ancho del modal** (`LegendList` en `legend_list.dart`): que cada fila de la leyenda ocupe todo el ancho disponible, con el nombre a la izquierda, el monto pegado a la derecha y la barra de color estirándose de borde a borde debajo. Reemplaza el `Wrap` de columnas de ancho fijo (220px) por una lista vertical a ancho completo. `LegendList` ya solo se usa en este modal (la leyenda inline se quitó en spec 17), por lo que el cambio no afecta otras pantallas.

**No incluye:**

- **Los demás bottom sheets** de la app (`categories_modal`, `category_editor_modal`, `expense_form`, `reminder_form`, `link_dialogs`, `shared_card`, `shared_expense_form`): quedan como están.
- **La altura del modal:** sigue siendo mínima (lo que ocupe título + leyenda), con scroll interno si hace falta. No se cambia.
- **La alineación del contenido:** título "POR CATEGORÍA" y nombres de categoría siguen alineados a la izquierda; solo cambia que el contenido ahora se estira a ancho completo (montos a la derecha, barras de borde a borde).
- **El resto del contenido del modal:** título, colores, fondo (`context.palette.surface`), esquinas redondeadas y forma de cierre (deslizar / tocar afuera) quedan intactos.
- **El botón "Más detalles"** y el resto de `DonutCard` / el carrusel: intactos.

---

## Modelo de datos

Este spec **no introduce ni modifica datos**. Es un ajuste puramente de layout/UI sobre el modal existente. No hay estructuras, constantes ni persistencia nuevas.

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Override del ancho por defecto** en `_showLegendSheet` (`donut_card.dart`): pasar `constraints: const BoxConstraints(minWidth: double.infinity)` a `showModalBottomSheet`. Anula el `maxWidth: 640` centrado de Material 3 y, con el `minWidth: double.infinity`, fuerza el ancho completo (un `BoxConstraints()` vacío no alcanza en teléfonos: al quitar el `minWidth` implícito el sheet se encoge al ancho del contenido). No se toca la altura (sigue definida por el contenido). *Verificación:* `flutter analyze` limpio.

2. **Ajustar el contenido al ancho** en `LegendList` (`legend_list.dart`): reemplazar el `Wrap` de `SizedBox(width: 220)` por un `Column` con `crossAxisAlignment.stretch`, de modo que cada fila (punto + nombre + monto a la derecha + barra) ocupe todo el ancho del modal. *Verificación:* `flutter analyze` limpio.

3. **Repaso visual e integración.** Abrir el modal desde el botón "Más detalles" en pantalla ancha (tablet / emulador grande) y angosta (teléfono): el sheet llega de borde a borde en ambos casos, con altura mínima igual que antes, título "POR CATEGORÍA" y `LegendList` alineados a la izquierda, fondo `surface`, esquinas redondeadas arriba y cierre por deslizar/tocar afuera funcionando. Verificar en tema claro y oscuro. *Verificación:* `flutter analyze` limpio, `flutter test` en verde y sin regresiones en el resto del home ni en los demás bottom sheets.

---

## Criterios de aceptación

- [ ] Al tocar "Más detalles", el modal bottom sheet ocupa **todo el ancho de la pantalla** (de borde a borde), tanto en pantallas anchas como angostas; ya no aparece centrado ni con márgenes laterales.
- [ ] La **altura** del modal sigue siendo mínima (lo que ocupan título + `LegendList`), con scroll interno si el contenido no entra.
- [ ] El **contenido** no cambia: título "POR CATEGORÍA" y `LegendList` siguen alineados a la izquierda, con el mismo fondo (`context.palette.surface`), esquinas redondeadas arriba y cierre por deslizar o tocar afuera.
- [ ] Los **demás bottom sheets** de la app (categorías, editor de categoría, formulario de gasto, recordatorios, compartidos, etc.) quedan sin cambios.
- [ ] El botón "Más detalles", el donut, el "+", el total del mes, la MovementsCard y el resto del carrusel quedan **intactos**.
- [ ] Se ve correcto en **tema claro y oscuro**.
- [ ] `flutter analyze` no reporta errores y `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Cómo forzar el ancho completo | Pasar **`constraints: const BoxConstraints(minWidth: double.infinity)`** a `showModalBottomSheet` | `BoxConstraints()` vacío (encoge el sheet al contenido en teléfonos) / definir `BottomSheetThemeData` global | Anula el `maxWidth: 640` centrado de Material 3 y fuerza el ancho completo sin tocar la altura ni el resto de la app. |
| Contenido a ancho completo | Cambiar `LegendList` a **`Column` con `stretch`** (filas de ancho completo) | Mantener el `Wrap` de columnas fijas de 220px | Con el modal a borde de borde, el contenido angosto dejaba el sheet vacío de un lado; `LegendList` ya solo vive en este modal, así que estirarlo no afecta otras pantallas. |
| Alcance del ancho | **Solo el modal de "Más detalles"** | Unificar el ancho de todos los bottom sheets vía tema global | El usuario pidió explícitamente tocar solo este modal; un cambio global arriesga regresiones en los otros sheets. |
| Altura del modal | **Mínima con scroll interno** (como hoy) | Volverlo `isScrollControlled` para permitir altura variable/expandida | El usuario confirmó conservar la altura mínima; no es parte del problema a resolver. |
| Alineación del contenido | **Sin cambios** (izquierda) | Centrar el contenido al ganar ancho | El pedido es solo de ancho del contenedor; el contenido queda igual. |

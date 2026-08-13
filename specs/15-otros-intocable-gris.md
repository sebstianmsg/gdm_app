# 15 — "Otros" intocable: sin editar y en gris

> **Estado:** Implementado
> **Dependencias:** spec 01 (categoría "Otros" no borrable, `is_deletable=false`, `delete_category` reasigna a Otros), spec 12 (columna `icon`, círculo color+ícono, lápiz de edición en cada fila), spec 11 (`AppPalette`/`context.palette`)
> **Fecha:** 2026-08-09
> **Objetivo (una frase):** Que la categoría no borrable "Otros" (detectada por `isDeletable == false`) quede **totalmente intocable** en la UI —sin lápiz, sin abrir el editor al tocar su círculo, sin cambio de nombre— y se **pinte siempre en un gris neutro** (anulación solo visual, sin tocar la DB) en **toda la app** donde se represente su color.

---

## Alcance

**Incluye:**

1. **Detección de "Otros" por `isDeletable == false`.** No se compara por el nombre literal; se reutiliza el flag que ya oculta la ✕ de borrado.

2. **Bloqueo de edición en la fila de "Otros"** (`categories_modal.dart`):
   - **No** se renderiza el ícono del lápiz (✎).
   - El círculo **no es clickeable** (sin `onTap`; no abre el editor).
   - Sigue **sin** la ✕ de borrado (comportamiento actual).
   - Resultado: la fila de "Otros" no ofrece ninguna acción de edición ni borrado, y su nombre no se puede cambiar.

3. **Color gris "solo visual" para "Otros", en toda la app.** Un helper/getter central devuelve el color a pintar: **gris neutro** si `!isDeletable`, o el color real de la categoría en cualquier otro caso. Se aplica en todos los lugares que hoy pintan el color de categoría:
   - Círculo del modal de categorías (`categories_modal.dart`).
   - Donut (`donut_painter.dart`) y su leyenda (`legend_list.dart`).
   - Filas de gasto (`expense_row.dart`) y el card de movimientos (`movements_card.dart`).
   - Chip de categoría (`category_chip.dart`).

4. **Gris neutro elegido:** `#9AA0A6` (gris medio, neutro y agradable; comunica "intocable" sin competir con la paleta de colores de las demás categorías).

**No incluye:**

- **Cambiar el color guardado** de "Otros" en la DB: la anulación es **solo visual**; la columna `color` no se modifica ni se corre migración.
- Tocar la lógica de `delete_category`, el trigger `handle_new_user` ni el `schema.sql`.
- Cambiar la **regla de "no repetir" colores** del selector: el color de "Otros" ya estaba fuera del flujo de edición; no se agrega el gris a la paleta seleccionable.
- Bloquear "Otros" desde el **backend** (RLS/constraints): el bloqueo es de UI. La DB ya impide borrarlo (`is_deletable=false`); este spec no agrega protección contra un `update` de nombre por fuera de la app.
- Cambiar el **ícono** de "Otros" (sigue resolviéndose con `resolveCategoryIcon`, típicamente `help`).

---

## Modelo de datos

Este spec **no introduce datos persistidos nuevos** ni modifica el esquema: no hay columnas, migraciones ni cambios en `schema.sql`. La única "estructura" es un **helper en código** para centralizar el color a mostrar.

**Constante + helper** (ubicación: `lib/features/categories/category_icons.dart`, junto a `resolveCategoryIcon`):

```dart
/// Gris neutro con el que se pinta la categoría intocable "Otros"
/// (no borrable). Es una anulación **solo visual**: no se persiste.
const String kUntouchableCategoryColor = '#9AA0A6';

/// Color hex a **mostrar** para una categoría: gris fijo si es la
/// categoría intocable (`!isDeletable`), o su color real en cualquier
/// otro caso. Centraliza la regla para toda la app.
String displayCategoryColor(Category category) =>
    category.isDeletable ? category.color : kUntouchableCategoryColor;
```

- Se implementa como **función libre** (no como getter `Category.displayColor`) para no cargar el modelo con reglas de presentación, coherente con `resolveCategoryIcon`, que también vive fuera del modelo.
- El comentario de `Category.color` ("siempre se pinta con este valor… nunca con constantes locales") se actualiza para reflejar que el color a **mostrar** pasa por `displayCategoryColor` (que introduce la única excepción: el gris de "Otros").

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Helper de color.** En `lib/features/categories/category_icons.dart` agregar `kUntouchableCategoryColor = '#9AA0A6'` y la función libre `displayCategoryColor(Category)`. Importar `Category` si hiciera falta. *Verificación:* `flutter analyze` limpio; `displayCategoryColor` devuelve gris para una categoría con `isDeletable=false` y el color real para el resto.

2. **Fila de "Otros" no editable** (`categories_modal.dart`, `_CategoryRow`). Cuando `!category.isDeletable`: no renderizar el `IconButton` del lápiz y pasar el círculo **sin `onTap`**. Ajustar `_CategoryCircle` para tolerar `onTap` nulo (ya es `VoidCallback?`; asegurar que sin `onTap` no muestre feedback de tap). *Verificación manual:* la fila de "Otros" no muestra lápiz ni ✕, y tocar su círculo no abre el editor; las demás filas siguen editables.

3. **Gris de "Otros" en el modal** (`categories_modal.dart`). El círculo de cada fila usa `colorFromHex(displayCategoryColor(category))` en vez de `colorFromHex(category.color)`. *Verificación manual:* "Otros" aparece en gris en la lista; las demás conservan su color.

4. **Gris en el donut y la leyenda** (`donut_painter.dart`, `legend_list.dart`). Reemplazar `_colorFromHex(s.category.color)` por el color derivado de `displayCategoryColor(s.category)`. *Verificación manual:* el segmento y la entrada de leyenda de "Otros" se ven grises.

5. **Gris en filas de gasto y card de movimientos** (`expense_row.dart`, `movements_card.dart`). Reemplazar el uso directo de `category.color` por `displayCategoryColor(category)` al construir el color. *Verificación manual:* los gastos de "Otros" muestran el gris; los de otras categorías, su color.

6. **Gris en el chip de categoría** (`category_chip.dart`). Aplicar `displayCategoryColor` al pintar el chip. *Verificación manual:* el chip de "Otros" se ve gris donde aparezca.

7. **Actualizar el comentario del modelo** (`category.dart`). Aclarar que el color a mostrar pasa por `displayCategoryColor` (excepción: gris de "Otros"). *Verificación:* comentario coherente; sin cambios de comportamiento.

8. **Repaso e integración.** `flutter analyze` limpio y `flutter test` en verde. Recorrido visual en tema claro y oscuro (spec 11): modal, donut, leyenda, filas y chip. Hacer un `grep` de `.color`/`colorFromHex` para confirmar que todos los consumidores pasan por el helper. *Verificación:* suite en verde y "Otros" gris + intocable en toda la app.

---

## Criterios de aceptación

- [ ] Existe `displayCategoryColor(Category)` (función libre en `category_icons.dart`) que devuelve `kUntouchableCategoryColor` (`#9AA0A6`) cuando `isDeletable == false` y `category.color` en cualquier otro caso.
- [ ] La categoría intocable se detecta por `isDeletable == false` (no por el nombre "Otros").
- [ ] En la lista de categorías, la fila de "Otros" **no** muestra el ícono del lápiz (✎).
- [ ] En la lista de categorías, la fila de "Otros" **no** muestra la ✕ de borrado (se mantiene el comportamiento previo).
- [ ] Tocar el círculo de "Otros" **no** abre el editor de categoría; el nombre de "Otros" no se puede cambiar desde la UI.
- [ ] Las demás categorías (borrables) siguen mostrando el lápiz, la ✕ y abren el editor al tocar el círculo o el lápiz.
- [ ] "Otros" se pinta en gris `#9AA0A6` en: círculo del modal, segmento del donut, entrada de la leyenda, filas de gasto, card de movimientos y chip de categoría.
- [ ] El gris es **solo visual**: el valor `color` de "Otros" en la DB no cambia y no se corre ninguna migración.
- [ ] Las categorías borrables conservan su color real en todos esos lugares.
- [ ] `flutter analyze` no reporta errores y `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Detección de "Otros" | **Flag `isDeletable == false`** | Comparar por nombre literal `"Otros"` | Robusto ante cambios de texto/idioma; es la misma condición que ya oculta la ✕. |
| Naturaleza del gris | **Anulación solo visual** (helper en runtime) | Cambiar el `color` guardado en la DB / migración | No ensucia el dato ni ocupa un color de la paleta; reversible y sin tocar el backend. |
| Alcance del gris | **Toda la app** (modal, donut, leyenda, filas, card, chip) | Solo el modal de categorías | Pedido explícito del usuario: "Otros" debe leerse como intocable en todas las vistas. |
| Ubicación del helper | **Función libre `displayCategoryColor` en `category_icons.dart`** | Getter `Category.displayColor` en el modelo / archivo `category_colors.dart` nuevo | El usuario lo definió así; mantiene las reglas de presentación fuera del modelo, coherente con `resolveCategoryIcon`. |
| Tono de gris | **`#9AA0A6`** (gris neutro) | `#8B968F` de la paleta (verdoso) / gris del tema | Neutro y agradable; comunica "intocable" sin competir con los colores de las demás categorías. |
| Bloqueo de edición | **Sacar lápiz + círculo sin `onTap`** | Dejar el lápiz pero deshabilitarlo (gris/no-op) | Un lápiz visible sugiere que se puede editar; quitarlo comunica mejor que "Otros" es intocable. |
| Protección del nombre | **Solo en la UI** | Constraint/RLS en la DB que impida `update` del nombre | El pedido es de UX; el bloqueo de UI alcanza. La DB ya impide borrarlo (`is_deletable=false`); endurecer el backend queda para otro spec si hiciera falta. |
| Ícono de "Otros" | **Sin cambios** (sigue `resolveCategoryIcon`, típicamente `help`) | Forzar un ícono específico para "Otros" | Fuera del objetivo; el foco es intocabilidad + color. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Queda algún lugar que pinta `category.color` directo y no se migra a `displayCategoryColor`, dejando "Otros" con su color viejo en esa vista. | Medio | El plan enumera los 6 consumidores conocidos (modal, donut, leyenda, filas, card, chip); en el paso 8 se hace un `grep` de `.color`/`colorFromHex` para confirmar que todos pasan por el helper. |
| Cada widget tiene su propia función local `_colorFromHex`, lo que invita a re-implementar la regla del gris en cada lado en vez de centralizarla. | Bajo | La regla vive solo en `displayCategoryColor`; los widgets siguen usando su `_colorFromHex` para convertir hex→Color, pero reciben el hex ya resuelto por el helper. |
| Si en el futuro existiera más de una categoría con `isDeletable == false`, todas se pintarían en gris. | Bajo | Hoy el modelo del sistema garantiza una única no borrable ("Otros"); es el comportamiento esperado de la regla. Documentado como decisión (detección por flag). |
| El gris `#9AA0A6` puede tener bajo contraste con el fondo en tema claro u oscuro (spec 11). | Bajo | En el círculo el ícono va en blanco sobre el gris (contraste suficiente); en el paso 8 se revisa visualmente en ambos temas y se ajusta el tono si hiciera falta. |
| El bloqueo es solo de UI: un `update` del nombre de "Otros" por fuera de la app seguiría siendo posible. | Bajo | Aceptado y documentado; el objetivo es de UX. Si se requiere garantía dura, se aborda en un spec de backend. |

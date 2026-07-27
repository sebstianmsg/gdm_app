# 02 — Formato de fecha día/mes/año y colores de categoría sin repetir

**Estado:** Implementado
**Fecha:** 2026-07-26
**Dependencias:** SPEC 01

**Objetivo (una frase):** Mostrar las fechas de gastos en formato `día/mes/año` (sin cambiar cómo se guardan) y ampliar la paleta de colores de categorías a 32, ocultando en el selector los colores ya usados para evitar duplicados.

---

## Alcance

**Dentro:**

1. **Formato de fecha visual (`día/mes/año`, dos dígitos):**
   - Nueva función de formato de display `formatDateEs(DateTime) → "26/07/2026"` (día y mes con cero a la izquierda).
   - Usar ese formato en **todos** los lugares donde hoy se muestra una fecha con `formatDateApi`:
     - Botón de fecha del modal "Agregar gasto" (`expense_form.dart`).
     - Botón de fecha de la fila de edición de un gasto (`expense_row.dart`).
   - `formatDateApi` (`YYYY-MM-DD`) **se mantiene intacto** para guardar/consultar en Supabase (`expenses_data.dart`, serialización de `Expense`).

2. **Paleta de colores ampliada a 32:**
   - Agregar 20 colores nuevos, distintos y variados, a los 12 actuales de `_colorPalette` (`categories_modal.dart`).

3. **Selector de color sin repetir:**
   - El diálogo "Elegir color" **oculta** los colores que ya usa alguna categoría.
   - Excepción: al editar una categoría existente, su **color actual** sigue visible y marcado como seleccionado, aunque esté "en uso" por ella misma.
   - Si **no hay colores libres** al crear una categoría nueva: deshabilitar "Agregar" y mostrar el mensaje "No hay colores libres" (Opción A).

**Fuera de alcance (para futuros specs):**

- Selector de color libre (rueda / hex arbitrario): la elección sigue siendo entre colores de la paleta fija.
- Cambiar el formato de fecha en otros lugares que no muestren fechas de gasto (ej. el selector de mes "Julio 2026", que no usa `formatDateApi`).
- Internacionalización / formatos de fecha por locale del dispositivo.
- Cambiar cómo se persiste la fecha en Postgres.

---

## Modelo de datos

Esta feature **no introduce nuevas estructuras de datos persistidas**. No toca `Expense`, `Category`, ni el schema de Supabase. Los únicos cambios son en la capa de presentación:

- **`formatDateEs(DateTime) → String`** (nueva función de display, junto a `formatDateApi` en `lib/models/expense.dart`):

  ```dart
  // "26/07/2026" — día/mes/año, día y mes con cero a la izquierda.
  // Solo para mostrar. La persistencia sigue usando formatDateApi (YYYY-MM-DD).
  String formatDateEs(DateTime date) => '$dd/$mm/$yyyy';
  ```

- **`_colorPalette`** (constante existente en `lib/features/categories/categories_modal.dart`): pasa de 12 a 32 entradas hex. Los 12 actuales se conservan; se agregan 20 nuevos, todos distintos entre sí.

  ```dart
  // 12 actuales + 20 nuevos = 32 hex '#RRGGBB', sin duplicados.
  const _colorPalette = [ /* ...32 colores... */ ];
  ```

- **Colores en uso** (derivado, no persistido): se calcula en tiempo de render como el conjunto de `category.color` (normalizado a mayúsculas) de las categorías actuales, usado para filtrar la paleta en el diálogo "Elegir color".

Convención de comparación: los hex se comparan normalizados a mayúsculas para evitar falsos negativos por `#ff6b6b` vs `#FF6B6B`.

---

## Plan de implementación

1. **Agregar `formatDateEs` en `lib/models/expense.dart`.** Nueva función que devuelve `día/mes/año` con dos dígitos. No se toca `formatDateApi` ni `parseDateApi`. Test manual: unit test de mapeo (`formatDateEs(DateTime(2026,7,26)) == '26/07/2026'`).

2. **Usar `formatDateEs` en el modal "Agregar gasto" (`expense_form.dart`).** Reemplazar `Text(formatDateApi(_date))` por `Text(formatDateEs(_date))` y ajustar el import. El valor enviado en `onSubmit` sigue siendo el `DateTime`. Test manual: abrir "Agregar gasto", el botón muestra `26/07/2026`.

3. **Usar `formatDateEs` en la fila de edición (`expense_row.dart`).** Reemplazar `formatDateApi(_date!)` por `formatDateEs(_date!)` en el botón de fecha. Test manual: editar un gasto, el botón muestra la fecha en `día/mes/año`.

4. **Ampliar `_colorPalette` a 32 en `categories_modal.dart`.** Agregar 20 hex nuevos, distintos y variados, después de los 12 existentes. Test manual: abrir "Elegir color" en una categoría, se ven más colores.

5. **Filtrar colores usados en `_pickColor`.** Pasar al diálogo el conjunto de colores en uso (normalizados a mayúsculas) y el color actual. Mostrar solo los colores libres, más el color actual recibido (que queda marcado como seleccionado). Test manual: si "Transporte" es azul, al abrir el picker de otra categoría el azul no aparece; al abrir el de "Transporte", el azul sí aparece y está marcado.

6. **Manejar el caso sin colores libres al crear.** En la fila de "Agregar" categoría: si todos los colores de la paleta están en uso, deshabilitar el botón "Agregar" y mostrar el mensaje "No hay colores libres". Test manual: usar todas las categorías hasta agotar la paleta, el botón queda deshabilitado con el mensaje.

---

## Criterios de aceptación

- [ ] `formatDateEs(DateTime(2026, 7, 26))` devuelve exactamente `"26/07/2026"`.
- [ ] `formatDateEs(DateTime(2026, 12, 5))` devuelve `"05/12/2026"` (día y mes con cero a la izquierda).
- [ ] El botón de fecha del modal "Agregar gasto" muestra la fecha en formato `día/mes/año`.
- [ ] El botón de fecha de la fila de edición de un gasto muestra la fecha en formato `día/mes/año`.
- [ ] `formatDateApi` sigue devolviendo `YYYY-MM-DD` y se usa sin cambios al guardar/consultar gastos en Supabase.
- [ ] La paleta `_colorPalette` tiene exactamente 32 colores, sin hex duplicados.
- [ ] En el diálogo "Elegir color", los colores ya usados por otras categorías no aparecen.
- [ ] Al editar una categoría, su color actual aparece en el diálogo y está marcado como seleccionado, aunque esté en uso por ella misma.
- [ ] Si todos los colores de la paleta están en uso, el botón "Agregar" categoría queda deshabilitado y se muestra el mensaje "No hay colores libres".
- [ ] `flutter test` pasa sin errores.

---

## Decisiones

- **Sí:** función de display separada `formatDateEs`, dejando `formatDateApi` intacta. La persistencia y las queries dependen del formato ISO; mezclarlos rompería el filtro por mes.
- **No:** cambiar `formatDateApi` a `día/mes/año`. Rompería `expenses_data.dart` (`.gte`/`.lt` sobre la columna `date`) y la serialización.
- **No:** usar `intl`/`DateFormat`. Es una sola función trivial; agregar dependencia y locale es sobredimensionar.
- **Sí:** día/mes en dos dígitos. Ancho fijo, más prolijo en los botones angostos de la fila de edición.
- **Sí:** paleta de 32 colores (12 actuales + 20 nuevos). Suficiente margen para que "sin colores libres" sea un caso raro.
- **No:** selector de color libre (hex/rueda). Mantener paleta fija hace trivial detectar duplicados; el color libre iría en otro spec.
- **Sí:** ocultar colores en uso, con excepción del color propio al editar. Cumple el objetivo (no repetir) sin bloquear la edición de una categoría existente.
- **Sí:** deshabilitar "Agregar" con mensaje cuando no hay colores libres (Opción A). Es explícito; permitir repetir como fallback contradiría el objetivo.
- **Sí:** comparar hex normalizados a mayúsculas. Evita que `#ff6b6b` y `#FF6B6B` se traten como colores distintos.

---

## Riesgos

| Riesgo | Mitigación |
| --- | --- |
| Una categoría tiene un color que no está en la paleta de 32 (ej. sembrado por el schema con otro hex). | Al editar, su color actual se agrega al diálogo aparte de la paleta, así siempre es visible y seleccionable. |
| Los datos actuales ya tienen dos categorías con el mismo color (previo a este spec). | El filtro solo evita *nuevas* repeticiones; no re-colorea lo existente. Corregir duplicados viejos es manual, fuera de alcance. |

## Lo que **no** está en este spec

- Selector de color libre (rueda / hex arbitrario).
- Formato de fecha por locale del dispositivo o con `intl`.
- Cambiar el formato de fecha del selector de mes ("Julio 2026").
- Cambiar cómo se persiste la fecha en Postgres.
- Re-colorear categorías que ya comparten color.

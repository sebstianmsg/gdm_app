# SPEC 29 — Grilla de colores de categoría adaptable al ancho (8 columnas fijas)

> **Estado:** Approved
> **Depende de:** SPEC 02 (paleta de 32 colores y filtrado de colores en uso), SPEC 11 (theming `context.palette`)
> **Fecha:** 2026-08-16
> **Objetivo (una frase):** Reemplazar el `Wrap` de la grilla de colores en el editor de categorías por una grilla de **8 columnas fijas** que reparte el espacio de forma pareja, para que se vea alineada e idéntica en todos los anchos de pantalla.

**Contexto:** en `_ColorSwatches` (`category_editor_modal.dart`) los círculos de color se acomodan con un `Wrap` de ancho fijo (36px) y `spacing: 10`, así que la cantidad de columnas depende del ancho del dispositivo (7 en el teléfono físico, 8 en el Pixel 7) y la última fila queda desalineada. Se quiere una grilla que se adapte al ancho manteniendo columnas alineadas.

---

## Alcance

**Dentro:**

1. Reemplazar el `Wrap` de `_ColorSwatches` (`lib/features/categories/category_editor_modal.dart`) por un `GridView` de **8 columnas fijas** (`SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8)`).
2. La grilla reparte el espacio horizontal sobrante de forma pareja entre las 8 columnas, de modo que siempre queden 8 alineadas sin importar el ancho del dispositivo.
3. Se conserva el comportamiento actual: círculos de color, marca de check en el seleccionado, borde blanco en el seleccionado, `onSelected` al tocar, y la lógica de filtrado de colores (libres + color propio) intacta.
4. La grilla usa `shrinkWrap: true` y no scrollea por sí misma (vive dentro del scroll del modal).

**Fuera de alcance:**

- El carrusel de **Símbolos** (grilla 4×2): queda igual, no se toca.
- Cambiar el **tamaño** de los círculos (siguen en 36px) o la paleta de colores.
- La lógica de qué colores se muestran (filtrado de "colores en uso" del SPEC 02).
- El selector de fecha, el de hora, u otros pickers.

---

## Modelo de datos

Esta feature **no introduce ni modifica datos ni estado persistente.** Solo cambia la capa de presentación de `_ColorSwatches`; `CategoryDraft`, la paleta y `usedColors` siguen igual.

---

## Plan de implementación

1. **Reemplazar el `Wrap` por un `GridView` de 8 columnas en `_ColorSwatches`.** Usar `GridView.count`/`GridView` con `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, crossAxisSpacing: <s>, mainAxisSpacing: <s>)`, `shrinkWrap: true`, `physics: NeverScrollableScrollPhysics()` y `padding: EdgeInsets.zero`. La lista `swatches` (libres + color propio) se mapea igual que hoy. *Verificación:* `flutter analyze` limpio; el editor abre y muestra 8 columnas.

2. **Mantener el círculo en 36px dentro de cada celda.** Como las celdas de la grilla son más anchas que 36px, envolver cada círculo en un `Center` (o `Align`) para que el círculo de 36×36 quede centrado en su celda y el espacio sobrante se reparta parejo. Ajustar `childAspectRatio` a 1 para celdas cuadradas. *Verificación:* los círculos no se deforman ni se estiran; quedan redondos y centrados.

3. **Verificación de alineación multi-ancho.** Probar en un ancho angosto (teléfono físico) y en el Pixel 7: en ambos deben verse **8 columnas alineadas**, con la última fila arrancando desde la izquierda y sin desborde horizontal. *Verificación manual:* comparar contra las capturas del reporte.

4. **Verificación integral.** `flutter analyze` sin errores y `flutter test` en verde (los tests existentes de categorías siguen pasando). Seleccionar un color sigue marcándolo con el check y borde blanco; el color propio al editar sigue visible y seleccionado.

---

## Criterios de aceptación

- [ ] La grilla de colores del editor de categorías se renderiza con un `GridView` de **8 columnas fijas**, no con `Wrap`.
- [ ] En un ancho angosto (teléfono físico) y en el Pixel 7 se ven **8 columnas alineadas**, con la última fila alineada a la izquierda y sin desborde horizontal.
- [ ] Los círculos siguen midiendo 36×36, redondos, sin deformarse ni estirarse, centrados en su celda.
- [ ] El espacio horizontal sobrante se reparte de forma pareja entre columnas.
- [ ] Seleccionar un color lo marca con check y borde blanco; el filtrado de colores en uso (SPEC 02) y el color propio al editar siguen funcionando igual.
- [ ] El carrusel de Símbolos no cambia.
- [ ] `flutter analyze` sin errores y `flutter test` en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Estrategia de grilla | 8 columnas fijas con reparto parejo (`GridView`) | Columnas dinámicas justificadas / seguir con `Wrap` | El usuario lo eligió: se ve idéntico y alineado en todos los anchos; el `Wrap` variaba las columnas según el dispositivo. |
| Tamaño de círculos | Fijo 36px, centrado en la celda | Escalar el círculo con el ancho | El usuario confirmó que el tamaño está bien; solo se reparte el espacio sobrante. |
| Alcance | Solo la grilla de colores | Tocar también los Símbolos | El carrusel de símbolos ya se ve bien; no hay motivo para arriesgarlo. |
| Nº de columnas | 8 | 7 u otro | 8 es lo que ya se veía bien en el Pixel 7 y encaja con la paleta de 32 (4 filas exactas). |

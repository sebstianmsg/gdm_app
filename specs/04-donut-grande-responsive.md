# 04 — Donut más grande y responsive, ajustado al ancho de la tarjeta

**Estado:** Implementado
**Fecha:** 2026-07-27
**Dependencias:** SPEC 03

**Objetivo (una frase):** Agrandar el gráfico de dona para que ocupe de forma responsive el ancho disponible de su tarjeta dejando solo 8px de respiro a cada lado antes del borde, escalando el grosor del anillo y los radios pero manteniendo fijos tanto el botón "+" central (96×96) como el tamaño de los números de porcentaje (≈20px).

---

## Alcance

**Dentro:**

1. **Donut responsive al ancho de la tarjeta.** En `donut_card.dart`, reemplazar el `SizedBox(width: 240, height: 240)` fijo por un tamaño calculado a partir del ancho disponible (vía `LayoutBuilder`): el donut es un cuadrado cuyo lado = ancho interno de la tarjeta − 8px de respiro a cada lado (16px total). El `CustomPaint` usa ese mismo tamaño.

2. **Respiro de 8px antes del borde.** El donut nunca toca el borde interno de la tarjeta: queda a 8px de cada lado. La tarjeta conserva su `padding: 20` actual, así que el respiro de 8px es *adicional* dentro de esa zona.

3. **Escalado proporcional del dibujo.** El `DonutPainter` ya escala desde el viewBox de 400 (radios y grosor del anillo). Al crecer el `size`, el anillo y los radios crecen proporcionalmente sin tocar la lógica del painter.

4. **Botón "+" fijo.** El `_AddButton` central se mantiene en 96×96, sin cambios, aunque el donut crezca.

5. **Números de porcentaje con tamaño fijo.** En `DonutPainter`, la fuente de los `%` pasa de `15 * scale * 2.2` (dependiente del tamaño) a un valor fijo ≈20px, para que se vean igual que hoy independientemente de cuánto crezca el donut.

**Fuera de alcance (para futuros specs):**

- Cambiar el layout de la leyenda (`LegendList`), los colores, o el gap entre slices.
- Cambiar el `padding: 20` de la tarjeta o su borde/`borderRadius`.
- Hacer responsive cualquier otro elemento de la pantalla (header, tarjetas de mes/movimientos).
- Un tope máximo de tamaño para el donut en pantallas muy anchas (tablets/desktop): por ahora crece con el ancho sin límite superior.

---

## Plan de implementación

1. **Fijar el tamaño de los números de % en `donut_painter.dart`.** Reemplazar `fontSize: 15 * scale * 2.2` por un valor fijo (`fontSize: 20`, el valor que hoy da al tamaño 240). No se toca nada más del painter: radios y grosor siguen derivándose de `scale`. *Test manual:* con el donut al tamaño actual los % se ven igual; al agrandarlo, los números no crecen.

2. **Hacer el donut responsive en `donut_card.dart`.** Envolver el bloque del donut en un `LayoutBuilder`; calcular `side = constraints.maxWidth - 16` (8px de respiro a cada lado). Reemplazar el `SizedBox(width: 240, height: 240)` y el `CustomPaint(size: const Size(240, 240))` por ese `side` calculado. El `Center` y el `Stack` con el `_AddButton` se conservan. *Test manual:* el donut ocupa casi todo el ancho de la tarjeta dejando ~8px a cada lado; el "+" sigue centrado y del mismo tamaño.

3. **Verificación integral.** `flutter analyze` limpio y `flutter test` verde; revisión visual en una pantalla angosta y en una ancha de que el donut se ajusta al ancho sin tocar los bordes, el "+" queda 96×96 y los % conservan su tamaño. *Test manual:* recorrer home con pocas y muchas categorías.

---

## Criterios de aceptación

- [ ] El donut ya no tiene tamaño fijo 240×240: su lado = ancho interno de la tarjeta − 16px (8px de respiro a cada lado).
- [ ] Entre el borde del donut y el borde interno de la tarjeta quedan exactamente 8px a cada lado; el donut nunca toca el borde.
- [ ] En una pantalla más ancha el donut se ve más grande; en una más angosta, más chico, siempre manteniendo la proporción cuadrada.
- [ ] El grosor del anillo y los radios escalan proporcionalmente con el tamaño del donut.
- [ ] El botón "+" central mide 96×96 en cualquier tamaño de donut.
- [ ] Los números de porcentaje se ven al mismo tamaño (≈20px) sin importar cuánto crezca el donut.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Cómo se define el tamaño | Responsive vía `LayoutBuilder` (ancho de la tarjeta − 16px) | Tamaño fijo mayor (ej. 300×300) | Se adapta a cualquier pantalla sin desbordar en las angostas ni quedar chico en las anchas. |
| Respiro antes del borde | 8px a cada lado | 16–20px | Pedido explícito del usuario: lo quiere lo más ajustado posible sin tocar el borde. |
| Tope máximo de tamaño | Sin límite superior | Cap para pantallas anchas | Fuera de alcance; la app apunta a móvil, se puede acotar en un spec futuro si hace falta. |
| Botón "+" central | Fijo 96×96 | Escalarlo con el donut | Pedido explícito: el "+" no se toca. |
| Números de % | Tamaño fijo ≈20px | Seguir con `15 * scale * 2.2` (escalable) | Pedido explícito: el tamaño actual de los números es el correcto y no debe crecer con el donut. |

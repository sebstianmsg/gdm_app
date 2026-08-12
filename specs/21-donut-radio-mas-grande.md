# SPEC 21 — Donut más grande: agrandar el radio del anillo para que llene su caja

> **Estado:** Approved
> **Depende de:** SPEC 04, SPEC 03
> **Fecha:** 2026-08-11
> **Objetivo:** Agrandar el radio del anillo del donut en `donut_painter.dart` (de `_outerRadius` 160 a ~196 sobre el viewBox de 400, subiendo `_innerRadius` a ~88 para conservar la proporción del grosor) para que el gráfico llene casi toda su caja cuadrada y deje de verse chico en el teléfono, manteniendo fijos el botón "+" (96×96) y el tamaño de los números de porcentaje (20px).

---

## Alcance

**Dentro:**

1. **Agrandar el radio exterior del anillo** en `donut_painter.dart`: `_outerRadius` pasa de `160` a `196` sobre el `viewBox` de `400`, dejando ~2px de margen (a escala del viewBox) para que el trazo del anillo no se corte contra el borde de la caja.

2. **Subir el radio interior en proporción** para conservar el grosor relativo actual: `_innerRadius` pasa de `72` a `88` (grosor del anillo 196−88 = 108; ratio grosor/exterior = 0.55, idéntico al actual). El `ringRadius` (media entre interior y exterior, donde se posicionan los `%`) se recalcula solo a partir de esas dos constantes.

3. **El resultado se propaga solo.** Como `_outerRadius` e `_innerRadius` ya alimentan `ringThickness`, `ringRadius` y la posición de las etiquetas, subir las dos constantes agranda el anillo, el hueco central y reubica los `%` sin más cambios en la lógica del painter.

**Fuera de alcance (para futuros specs):**

- **Tope máximo de tamaño en pantallas anchas** (tablets/desktop): el donut sigue creciendo con el ancho sin límite superior. Se deja constancia explícita: si en el futuro se apunta a pantallas grandes, un cap va en su propio spec.
- Cambiar el tamaño del `SizedBox`/caja del donut (`donut_card.dart`) o el respiro de 8px de la spec 04: la caja ya ocupa el ancho de la tarjeta, no se toca.
- Cambiar el botón "+" central (queda fijo en 96×96).
- Cambiar el `fontSize: 20` de los números de porcentaje (quedan igual).
- Tocar los colores, el gap entre slices, el orden de los slices o la leyenda (`LegendList` / "Más detalles").

---

## Modelo de datos

Este spec **no introduce ni modifica datos**. El único cambio son dos constantes de dibujo (`_outerRadius`, `_innerRadius`) en `donut_painter.dart`. No hay estructuras, columnas ni persistencia nuevas.

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Subir las dos constantes en `donut_painter.dart`.** Cambiar `_outerRadius` de `160` a `196` y `_innerRadius` de `72` a `88`. No se toca nada más: `ringThickness`, `ringRadius` y la posición de las etiquetas se derivan solos de esas constantes. *Verificación:* `flutter analyze` limpio; el donut se ve notablemente más grande y llena casi toda su caja.

2. **Confirmar que el hueco central sigue tapando bien el "+".** Con `_innerRadius` a 88, verificar que el botón "+" (96×96 fijo) queda dentro del hueco sin que el anillo lo pise, en un ancho de teléfono típico. Si el hueco quedara justo, ajustar levemente `_innerRadius` (no menos de 88 para no engrosar de más). *Verificación:* revisión visual en el teléfono / emulador angosto: el "+" no toca el anillo.

3. **Repaso visual e integración.** En tema claro y oscuro, con pocas y muchas categorías: el donut se ve grande y ajustado a la tarjeta, los `%` (20px) legibles sobre los slices, el "+" centrado y del mismo tamaño, sin desbordes ni cortes del trazo contra el borde. *Verificación:* `flutter analyze` sin errores y `flutter test` en verde, sin regresiones en la card del donut.

---

## Criterios de aceptación

- [ ] `_outerRadius` vale `196` y `_innerRadius` vale `88` en `donut_painter.dart`.
- [ ] El anillo del donut llena casi toda su caja cuadrada (deja solo ~2px de margen a escala del viewBox); ya no se ve el ~20% de aire vacío alrededor.
- [ ] En el teléfono el donut se percibe claramente más grande que antes.
- [ ] El grosor del anillo conserva la proporción actual (ratio grosor/exterior ≈ 0.55).
- [ ] El botón "+" central mide 96×96 y queda dentro del hueco sin ser pisado por el anillo.
- [ ] Los números de porcentaje se ven a `fontSize: 20`.
- [ ] El trazo del anillo no se corta ni desborda contra el borde de la caja en pantalla angosta.
- [ ] Se ve correcto en tema claro y oscuro.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Dónde está el problema | Agrandar el **radio dibujado** (`_outerRadius`) en el painter | Agrandar la caja/`SizedBox` en `donut_card.dart` | La caja ya ocupa el ancho de la tarjeta (spec 04); el aire venía de que el círculo se dibujaba al 80% del viewBox. |
| Cuánto agrandar el radio exterior | `_outerRadius` a **196** (~2px de margen) | 180 (deja más aire) | El usuario quiere sensación de "grande": llenar casi toda la caja. |
| Grosor del anillo | **Mantener la proporción actual** subiendo `_innerRadius` a 88 (ratio 0.55) | Dejar el anillo más grueso subiendo solo el exterior | Conserva el look actual del anillo y mantiene el hueco central acorde al "+". |
| Botón "+" central | **Fijo 96×96** | Escalarlo con el donut | Pedido explícito; coherente con spec 04. |
| Números de % | **Fijos en 20px** | Subirlos al agrandar el anillo | Pedido explícito: el tamaño actual es el correcto. |
| Tope máximo de tamaño | **Sin límite superior** (fuera de alcance) | Cap para pantallas anchas | La app apunta a móvil; se deja constancia para un spec futuro si se apunta a pantallas grandes. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| En un ancho de tarjeta muy chico, el hueco central (radio 88 escalado) podría acercarse al "+" fijo de 96px y el anillo pisar el botón. | El "+" se ve tapado o pegado al anillo. | Verificación visual del paso 2 en emulador angosto; si queda justo, subir levemente `_innerRadius` sin bajar de 88. |
| Con `_outerRadius` a 196 (casi el borde del viewBox de 200), el trazo del anillo podría cortarse contra el borde de la caja. | El anillo se ve "recortado" arriba/abajo/lados. | Se deja ~2px de margen (196 vs 200) a escala del viewBox; verificado en el paso 3. |

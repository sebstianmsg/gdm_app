# SPEC 30 — Efecto 3D (volumen) en el anillo del donut para que deje de verse plano

> **Estado:** Implementado
> **Depende de:** SPEC 04 (donut responsive), SPEC 21 (radios del anillo), SPEC 03 (paleta/theming)
> **Fecha:** 2026-08-16
> **Objetivo (una frase):** Dar sensación de relieve al anillo del donut en `donut_painter.dart` agregando una **sombra proyectada** debajo del anillo y un **bisel/gradiente en el grosor** de cada slice (borde interior más oscuro, exterior con brillo) más una **sombra leve en los números de `%`**, sin inclinar el gráfico ni tocar el botón "+" (96×96), la posición de las etiquetas ni la lógica de slices.

---

## Alcance

**Dentro:**

1. **Sombra proyectada del anillo.** En `donut_painter.dart`, antes de dibujar los slices, pintar una sombra circular difusa (blur) apenas desplazada hacia abajo, debajo del trazo del anillo, para que el aro parezca despegado de la tarjeta. Misma sombra en tema claro y oscuro.
2. **Bisel/gradiente en el grosor de cada slice.** Cada slice deja de pintarse con color plano y pasa a usar un gradiente a lo ancho del grosor del anillo: borde **interior más oscuro** y borde **exterior con brillo/aclarado** del color de la categoría, para dar sensación tubular/abombada. Se conserva el color base de cada categoría (`displayCategoryColor`).
3. **Sombra leve en los `%`.** Los números de porcentaje siguen en blanco, tamaño 20, misma posición; se les agrega una `Shadow` sutil para que se despeguen del relieve.
4. El efecto se ve **igual en tema claro y oscuro** (mismos parámetros).
5. Se conservan intactos: forma de **anillo con hueco**, radios (SPEC 21), gap entre slices, orden de slices, posición de las etiquetas, botón "+" central (96×96) y el placeholder de "sin categorías".

**Fuera de alcance:**

- **Inclinar el gráfico en perspectiva** o extruir una pared inferior (torta 3D clásica): descartado explícitamente, el anillo sigue de frente y redondo.
- Volverlo **torta llena** (sin hueco): sigue siendo anillo.
- Cambiar **radios, grosor, tamaño de la caja, botón "+" o tamaño de fuente** de los `%`.
- Cambiar **colores base** de las categorías, la leyenda (`LegendList`/"Más detalles") o el gap entre slices.
- Animaciones o transiciones del efecto.

---

## Modelo de datos

Este spec **no introduce ni modifica datos ni estado persistente.** Solo cambia la capa de dibujo de `DonutPainter`: `CategorySummary`, `displayCategoryColor`, la paleta y todo lo demás siguen igual. Los cambios son puramente de pintado (sombra, gradiente y sombra de texto) dentro de `donut_painter.dart`.

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Sombra proyectada del anillo.** En `paint()`, antes del loop de slices, dibujar un arco circular completo (`drawArc` stroke, radio = `ringRadius`, grosor = `ringThickness`) en un color oscuro semitransparente (p. ej. `Colors.black` con alpha ~0.25) sobre un `Paint` con `MaskFilter.blur(BlurStyle.normal, <sigma>)`, con el `rect` desplazado unos pocos px hacia abajo (a escala del viewBox). Va tapado luego por los slices, dejando ver solo el halo inferior. *Verificación:* `flutter analyze` limpio; el anillo se ve "despegado" de la tarjeta.

2. **Gradiente/bisel en cada slice.** Reemplazar el `Paint()..color = ...` plano de cada slice por un `shader` de gradiente que varíe a lo ancho del grosor del anillo: color de la categoría **oscurecido** hacia el radio interior y **aclarado** hacia el exterior. Se puede usar un `RadialGradient` centrado en el centro del donut (con `stops` en el rango interior→exterior del anillo) o un `SweepGradient`/degradé equivalente; se elige el que dé el look tubular sin romper el trazo `stroke`. Derivar los tonos oscuro/claro del color base con `HSLColor` (bajar/subir `lightness`). El gap entre slices y el orden se mantienen. *Verificación:* cada slice se ve abombado (interior oscuro, exterior con brillo) conservando su color; en tema claro y oscuro se ve igual.

3. **Sombra leve en los `%`.** Agregar a la `TextStyle` de los porcentajes una lista `shadows: [Shadow(color: black~0.4, blur ~2, offset (0, 1))]`, sin cambiar color (blanco), tamaño (20) ni posición. *Verificación:* los números se despegan del relieve y siguen legibles.

4. **Repaso visual e integración.** En tema claro y oscuro, con pocas y muchas categorías: el anillo se ve con volumen y sombra, los slices abombados, los `%` legibles, el "+" centrado y del mismo tamaño, sin desbordes ni cortes del trazo contra el borde de la caja. Ajustar finamente sigma de blur, offset de la sombra y delta de lightness del gradiente hasta que quede natural. *Verificación:* `flutter analyze` sin errores y `flutter test` en verde (sin regresiones en la card del donut); revisión visual en teléfono/emulador.

---

## Criterios de aceptación

- [ ] El anillo del donut proyecta una **sombra difusa** hacia abajo que lo despega visualmente de la tarjeta.
- [ ] Cada slice se pinta con un **gradiente en el grosor** del anillo: borde interior más oscuro y borde exterior más claro/brilloso, conservando el color base de la categoría.
- [ ] Los slices se perciben **abombados/tubulares**, no planos.
- [ ] Los números de `%` siguen en **blanco, tamaño 20, misma posición**, y tienen una **sombra leve** que los despega del relieve sin perder legibilidad.
- [ ] El efecto se ve **igual en tema claro y oscuro** (mismos parámetros).
- [ ] El gráfico **no se inclina** ni se extruye: sigue siendo un anillo de frente, redondo, con hueco.
- [ ] Se conservan radios (SPEC 21), grosor, gap entre slices, orden, caja del donut y botón "+" (96×96) sin cambios.
- [ ] El placeholder de "sin categorías" sigue funcionando (con o sin la sombra, sin romperse).
- [ ] El trazo del anillo (y su sombra) no se corta ni desborda contra el borde de la caja en pantalla angosta.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Tipo de efecto 3D | **Volumen sin inclinar** (sombra proyectada + bisel/gradiente en el grosor) | Torta 3D clásica inclinada en perspectiva con pared extruida | La versión inclinada deforma el círculo a elipse y complica el "+" central y las etiquetas; el usuario eligió el volumen de frente. |
| Componentes del volumen | **Las dos:** sombra proyectada + gradiente/bisel en el grosor | Solo una de las dos | El usuario confirmó que quiere ambas; juntas rompen mejor la sensación plana. |
| Forma base | **Anillo con hueco** (se mantiene) | Volverlo torta llena sin hueco | Sin hueco no habría dónde tapar el botón "+"; el usuario pidió mantener el anillo. |
| Botón "+" y `%` | **Se mantienen** en posición y tamaño (96×96 y fontSize 20) | Reubicarlos por el efecto | Pedido explícito del usuario; coherente con SPEC 04 y SPEC 21. |
| Sombra en los `%` | **Sombra leve de texto** | Dejarlos planos en blanco | El usuario la pidió para que no se pierdan sobre el brillo del relieve. |
| Parámetros por tema | **Mismos en claro y oscuro** | Sombra/brillo distintos por tema | El usuario quiere que se vea igual en ambos; simplifica el painter. |
| Verificación | **Visual** + `flutter analyze`/`flutter test` existentes | Test automatizado por píxel del painter | El efecto es puramente visual y el painter no es fácil de testear pixel a pixel. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| La sombra con `MaskFilter.blur` sobre un radio cercano al borde del viewBox (SPEC 21, `_outerRadius` 196) podría cortarse o desbordar contra el borde de la caja. | La sombra se ve recortada o pisa el borde de la tarjeta. | Mantener el desplazamiento y el sigma chicos; verificar en pantalla angosta (paso 4). Si se corta, reducir offset/sigma. |
| Un gradiente muy marcado (delta de lightness alto) podría alterar la percepción del color base de la categoría y no coincidir con la leyenda (`LegendList`). | El usuario ve un color distinto en el donut que en la leyenda. | Usar un delta de lightness moderado alrededor del color base; verificar contra la leyenda en el paso 4. |
| El blur y los shaders por slice agregan costo de pintado en cada repaint. | Posible micro-lag en dispositivos viejos al repintar el donut. | El donut repinta solo cuando cambian los `summaries` (`shouldRepaint`); el costo es acotado. Verificación visual de fluidez en el paso 4. |

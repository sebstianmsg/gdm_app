# 20 — Chip "Pendiente": animación de llenado verde al tocar para marcar pagado

> **Estado:** Implementado
> **Dependencias:** spec 19 (`_PendingChip` en `reminders_card.dart`, `_PaidBadge`, `_kPendingAmber`, acción `payReminder`), spec 16 (lógica de PAGO / ciclo / notificaciones), spec 11 (`context.palette`, tema claro/oscuro)
> **Fecha:** 2026-08-11
> **Objetivo (una frase):** Al tocar una vez el chip ámbar "Pendiente" de la card 3, reproducir una animación rápida (~400 ms) de llenado verde de izquierda a derecha y, al completarse, mostrar la etiqueta "Pagado", disparando el pago real (`payReminder`) en paralelo desde el inicio del toque.

---

## Alcance

**Incluye:**

1. **Convertir `_PendingChip` en un widget con estado y animación** (`reminders_card.dart`): pasa de `ConsumerWidget` a `ConsumerStatefulWidget` con un `AnimationController` de **~400 ms**. Al tocarlo una sola vez (sin hold):
   - Se dispara la animación de **llenado verde de izquierda a derecha** por encima del fondo ámbar (el verde "pinta" el chip progresivamente de 0% a 100% del ancho).
   - Durante el barrido el texto sigue diciendo **"Pendiente"** con el ícono de reloj (el verde solo cubre por encima).
   - El chip queda **deshabilitado** mientras corre la animación (toques repetidos se ignoran; no se paga dos veces).
   - Al **completarse** el barrido, el chip se reemplaza por el badge **"Pagado"** existente (`_PaidBadge`, ✓ apagado).

2. **Disparar el pago en paralelo** (opción A): `payReminder(...)` se ejecuta **al iniciar el toque**, junto con la animación, no al final. Cuando el barrido termina, el estado "Pagado" ya está resuelto y la card muestra `_PaidBadge`.

3. **Reintroducir la constante de verde** `_kPagoGreen` (mismo verde de spec 16) en `reminders_card.dart` como color del barrido.

**No incluye:**

- **Cambiar la lógica de `payReminder`** (crear gasto, marcar `paid_cycle`, cancelar notificación): idéntica a spec 16.
- **Modo hold / mantener presionado:** se descarta explícitamente; es un toque único.
- **Cambiar el estado ámbar "Pendiente"** (texto, ícono de reloj, `_kPendingAmber`) ni el badge **"Pagado"** (spec 19): quedan igual salvo la animación intermedia.
- **Tocar otras cards** (donut, movimientos, compartidos), el estado vacío, el encabezado, el botón `+` ni el formulario (`reminder_form.dart`).

---

## Modelo de datos

Este spec **no introduce ni modifica datos**. El único estado nuevo es efímero y de UI: un `AnimationController` (y un flag de "pagando" para deshabilitar) que viven en el `State` del chip mientras dura el barrido. No hay estructuras, columnas ni persistencia nuevas.

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Reintroducir el verde.** Agregar la constante `const Color _kPagoGreen = Color(0xFF...)` (el mismo verde de PAGO de spec 16) en `reminders_card.dart`, junto a `_kPendingAmber`. *Verificación:* `flutter analyze` limpio.

2. **Convertir `_PendingChip` a stateful con animación.** Cambiar de `ConsumerWidget` a `ConsumerStatefulWidget` con `SingleTickerProviderStateMixin`. Agregar un `AnimationController(duration: 400 ms)` y un flag `_paying`. En `onTap`: si `_paying` ya es `true`, ignorar; si no, poner `_paying = true`, llamar `payReminder(context, ref, reminder)` (en paralelo, sin await bloqueante) y `_controller.forward()`. Envolver el contenido (Row reloj + "Pendiente") en un pintado de llenado verde: un `AnimatedBuilder` con `ClipRect` + `Align(widthFactor: _controller.value, alignment: Alignment.centerLeft)` sobre una capa verde (`_kPagoGreen`) por encima del fondo ámbar, de izquierda a derecha. El texto/ícono "Pendiente" permanecen visibles debajo. Disponer `dispose()` del controller. *Verificación:* `flutter analyze` limpio.

3. **Transición a "Pagado".** Al completar la animación (`AnimationStatus.completed` o cuando `payReminder` ya refrescó el estado), la card se reconstruye con `isPaid == true` y renderiza `_PaidBadge`. Confirmar que el barrido llega al 100% antes de que el chip desaparezca (que no haya salto brusco): la card ya escucha el provider de recordatorios, así que al marcarse pagado el `else _PendingChip` pasa a `if (isPaid) _PaidBadge`. Si `payReminder` resuelve antes de terminar la animación, se deja completar el barrido igual (bien rápido, 400 ms). *Verificación:* `flutter analyze` limpio.

4. **Repaso visual e integración.** En **tema claro y oscuro**, con recordatorios pendientes: tocar el chip una vez dispara el barrido verde de izquierda a derecha en ~400 ms; durante el barrido el chip no responde a más toques; al terminar aparece "Pagado" (badge apagado con ✓) y el gasto quedó creado con la notificación cancelada. Verificar que no se paga dos veces con toques rápidos y que el chip no desborda el ancho de la fila. *Verificación:* `flutter analyze` sin errores y `flutter test` en verde, sin regresiones en la card 3 ni en el resto del carrusel.

---

## Criterios de aceptación

- [ ] Al **tocar una sola vez** el chip "Pendiente" (sin mantener presionado) se dispara una animación de **llenado verde de izquierda a derecha**.
- [ ] La animación dura **~400 ms** (se percibe rápida, tipo "snap").
- [ ] El verde del barrido es el mismo **`_kPagoGreen`** de spec 16 (el color del antiguo botón "PAGO").
- [ ] Durante el barrido, el chip muestra el texto **"Pendiente"** con el ícono de reloj (el verde pinta por encima del fondo ámbar).
- [ ] Mientras corre la animación, el chip queda **deshabilitado**: toques repetidos se ignoran y `payReminder` **no se ejecuta dos veces**.
- [ ] `payReminder` se dispara **al iniciar el toque** (en paralelo con la animación), ejecutando la misma lógica de spec 16 (crea el gasto, marca el ciclo pagado, cancela la notificación).
- [ ] Al **completarse** el barrido, el chip se reemplaza por la etiqueta **"Pagado"** existente (`_PaidBadge`, ✓ apagado/`textMuted`), sin cambios respecto a spec 19.
- [ ] El chip entra en el ancho disponible de la fila **sin desbordar** durante la animación.
- [ ] Se ve correcto en **tema claro y oscuro**.
- [ ] `flutter analyze` no reporta errores y `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Interacción | **Un solo toque** dispara la animación | Hold / mantener presionado | El usuario quiere sensación instantánea de "pago"; un hold agrega fricción innecesaria. |
| Duración del barrido | **~400 ms** | ~300 ms (muy snap) / ~600 ms (más lento) | Se percibe rápido pero deja ver el barrido verde; equilibrio confirmado por el usuario. |
| Momento del pago real | **Al iniciar el toque, en paralelo** (opción A) | Ejecutar `payReminder` al terminar la animación | Se siente instantáneo; al terminar el barrido el estado "Pagado" ya está resuelto sin latencia extra. |
| Color del barrido | **Reutilizar `_kPagoGreen`** de spec 16 | Un verde nuevo | El verde ya comunicaba "pagado/ok" en la app; mantiene coherencia y reaprovecha el color que había quedado sin uso. |
| Texto durante el barrido | **"Pendiente" fijo**, verde pinta por encima; "Pagado" recién al final | Cambiar el texto a "Pagado" apenas empieza el llenado | Evita que el texto y el estado real queden desincronizados; la transición a `_PaidBadge` marca el fin. |
| Chip durante la animación | **Deshabilitado** (ignora toques) | Permitir toques repetidos | Previene pagar dos veces / disparar la acción en paralelo; robustez ante toques rápidos. |
| Implementación del llenado | **`AnimationController` + `ClipRect`/`Align(widthFactor)`** sobre capa verde | Gradiente animado / `TweenAnimationBuilder` suelto | `Align(widthFactor)` con `centerLeft` da el barrido exacto de izquierda a derecha con control de duración y estado. |
| Alcance | **Solo la animación del chip de la card 3** | Tocar lógica de `payReminder`, notificaciones o el badge "Pagado" | Es un ajuste de UI; cambiar la lógica arriesga regresiones en spec 16 sin necesidad. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| `payReminder` refresca el estado (`isPaid == true`) **antes** de que termine el barrido y el chip desaparece a mitad de animación (salto brusco a `_PaidBadge`). | Se pierde la sensación de "llenado completo"; se ve un corte. | Dejar que el barrido complete sus ~400 ms igual; la transición a `_PaidBadge` se percibe como el cierre natural de la animación (paso 3). |
| Toques rápidos repetidos disparan `payReminder` más de una vez (doble gasto). | Gasto duplicado / estado inconsistente. | Flag `_paying` que deshabilita el chip apenas empieza la animación (paso 2). |
| El controller no se libera y queda un leak si la card se desmonta durante la animación. | Fuga de recursos / warning en debug. | `dispose()` del `AnimationController` en el `State` (paso 2). |

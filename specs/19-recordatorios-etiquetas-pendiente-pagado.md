# 19 — Recordatorios: etiquetas "Pendiente" (chip ámbar) y "Pagado"

> **Estado:** Implementado
> **Dependencias:** spec 16 (Card 3 de recordatorios: `reminders_card.dart`, `_PagoButton`, `_PaidBadge`, constante `_kPagoGreen`, acción `payReminder`), spec 11 (`context.palette`, tema claro/oscuro)
> **Fecha:** 2026-08-11
> **Objetivo (una frase):** En la card 3 de recordatorios, renombrar el botón verde "PAGO" a un chip accionable **"Pendiente"** con **ícono de reloj** y color **ámbar/naranja** (para que el color comunique "aún no pagado" y no se lea como "hecho"), conservando la acción de marcar pagado al tocarlo, y dejando la etiqueta resuelta **"Pagado"** exactamente como está.

---

## Alcance

**Incluye:**

1. **Chip "Pendiente" accionable** (`_PagoButton` en `reminders_card.dart:212`, se renombra a algo tipo `_PendingChip`):
   - Reemplaza el texto **"PAGO"** por **"Pendiente"**.
   - Agrega un **ícono de reloj** (ej. `Icons.schedule` / `Icons.access_time`) a la izquierda del texto.
   - Cambia el color de fondo de **verde** (`_kPagoGreen`) a **ámbar/naranja** fijo (color concreto en la sección de decisiones), con texto/ícono en color que garantice contraste en tema claro y oscuro.
   - **Conserva la acción intacta:** al tocarlo sigue ejecutando `payReminder(...)` (crea el gasto, marca `paid_cycle`, cancela la notificación). Solo cambia texto, ícono y color.

2. **Etiqueta "Pagado"** (`_PaidBadge`, `reminders_card.dart:182`): queda **exactamente igual** (texto "Pagado", ícono `Icons.check`, color `textMuted`/apagado). No se toca.

**No incluye:**

- **Cambiar la lógica de PAGO / ciclo / notificaciones:** el comportamiento al tocar el chip es idéntico al de spec 16.
- **Renombrar la acción `payReminder` ni la tabla/columnas** (`bill_reminders`, `paid_cycle`, etc.): son nombres internos, no visibles.
- **Cambiar el estado vacío, el encabezado, el botón `+`, el formulario** (`reminder_form.dart`) ni cualquier otra parte de la card 3.
- **Tocar otras cards** (donut, movimientos, compartidos) ni otros textos de la app.
- **Reintroducir el verde** en la card: tras el cambio, el verde `_kPagoGreen` deja de usarse para el chip (se elimina o queda sin referencias).

---

## Modelo de datos

Este spec **no introduce ni modifica datos**. Es un cambio puramente de texto/ícono/color sobre widgets existentes de la card 3. No hay estructuras, columnas ni persistencia nuevas.

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Renombrar y reestilar el chip pendiente** en `reminders_card.dart`: renombrar `_PagoButton` → `_PendingChip` (y sus usos), reemplazar el texto `'PAGO'` por `'Pendiente'`, anteponer un `Icon(Icons.schedule, size: 14, ...)` con `SizedBox(width: 4)` (mismo patrón visual que `_PaidBadge`), y cambiar el fondo de `_kPagoGreen` al **ámbar/naranja** fijo. Ajustar la constante de color: reemplazar `_kPagoGreen` por `_kPendingAmber` (color y comentario actualizados). Mantener `onTap: () => payReminder(...)` sin cambios. *Verificación:* `flutter analyze` limpio; sin referencias colgando a `_kPagoGreen`/`_PagoButton`.

2. **Confirmar que `_PaidBadge` no se toca** y que los comentarios/docstrings que mencionaban "PAGO" en el archivo se actualizan para no quedar desincronizados con el nuevo nombre. *Verificación:* `flutter analyze` limpio.

3. **Repaso visual e integración.** Abrir la card 3 con recordatorios pendientes y pagados en **tema claro y oscuro**: el chip pendiente se ve ámbar con el reloj y el texto "Pendiente" legible; al tocarlo sigue creando el gasto y pasando el recordatorio a "Pagado" (badge apagado con ✓); el chip entra en el ancho disponible sin desbordar. *Verificación:* `flutter analyze` sin errores y `flutter test` en verde, sin regresiones en la card 3 ni en el resto del carrusel.

---

## Criterios de aceptación

- [ ] En la card 3, el control accionable de un recordatorio **no pagado** muestra el texto **"Pendiente"** (ya no "PAGO").
- [ ] Ese chip lleva un **ícono de reloj** a la izquierda del texto.
- [ ] El chip pendiente tiene fondo **ámbar/naranja** (ya no verde), con texto e ícono legibles y con contraste suficiente en **tema claro y oscuro**.
- [ ] Al **tocar** el chip "Pendiente" se ejecuta la misma acción que antes: se crea el gasto, se marca el ciclo como pagado y se cancela la notificación (comportamiento de spec 16 intacto).
- [ ] Una vez pagado, el recordatorio muestra la etiqueta **"Pagado"** exactamente como hasta ahora (texto "Pagado", ícono ✓, color apagado/`textMuted`), sin cambios.
- [ ] El verde `_kPagoGreen` deja de usarse en la card (sin referencias colgando).
- [ ] El chip entra en el ancho disponible de la fila sin desbordar.
- [ ] `flutter analyze` no reporta errores y `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Texto del control no pagado | **"Pendiente"** | "PAGAR" / "PAGO" | El pago no se hace desde la app; el chip marca el estado y sirve para registrar que ya está pago. "PAGAR" sugeriría un cobro dentro de la app. |
| Semántica del chip | **Estado accionable** (muestra estado, al tocar marca pagado) | Botón de acción clásico | Un estado "Pendiente" comunica mejor la situación del recordatorio; conserva la acción al tocarlo sin cambiar la lógica. |
| Color del chip pendiente | **Ámbar/naranja fijo** (`_kPendingAmber`, ej. `Color(0xFFB45309)`) | Mantener el verde `_kPagoGreen` | El verde se lee como "hecho/ok"; el ámbar comunica "aún no pagado" y libera el verde. Color fijo (no de paleta) para garantizar contraste con texto claro en ambos temas, igual que hacía `_kPagoGreen`. |
| Ícono | **Reloj** (`Icons.schedule`) en el chip pendiente + ✓ en "Pagado" | Solo texto en el pendiente | El usuario pidió el reloj; refuerza el significado de "Pendiente" y equilibra visualmente con el ✓ del badge pagado. |
| Etiqueta resuelta | **"Pagado" sin cambios** | Rediseñarla junto con el pendiente | El estado resuelto ya funciona; el usuario lo dejó explícitamente como está. |
| Alcance del cambio | **Solo texto/ícono/color de la card 3** | Tocar lógica de PAGO, notificaciones o nombres internos | Es un ajuste de UI; cambiar la lógica arriesga regresiones en spec 16 sin necesidad. |

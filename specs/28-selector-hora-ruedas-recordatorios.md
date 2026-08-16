# SPEC 28 — Selector de hora tipo alarma (ruedas) en recordatorios

> **Estado:** Implementado
> **Depende de:** SPEC 16 (form de recordatorios), SPEC 11 (theming `context.palette`)
> **Fecha:** 2026-08-16
> **Objetivo (una frase):** Reemplazar el dial de reloj de Material por un selector de ruedas deslizables (estilo alarma de teléfono) para elegir la hora de notificación del recordatorio, conservando el resto del form intacto.

**Contexto:** al crear/editar un recordatorio de pago, el campo "Hora de la notificación" abre el `showTimePicker` de Material (reloj con dial giratorio). Ese formato le resulta poco intuitivo al usuario tanto en el emulador como en su teléfono físico. Quiere algo mucho más simple, **como poner la alarma del teléfono**: ruedas que se deslizan para hora y minuto. El único punto de cambio es `_pickTime` en `lib/features/reminders/reminder_form.dart`.

---

## Alcance

**Dentro:**

1. Nuevo selector de hora con **ruedas deslizables** (hora + minuto) presentado en un `showModalBottomSheet`, coherente con el estilo del resto del form (palette, radio, botón de confirmar).
2. Reemplazo de la implementación de `_pickTime` en `reminder_form.dart` para abrir ese selector en lugar de `showTimePicker`.
3. El selector inicializa en `_time` actual y devuelve un `TimeOfDay`; el `_FieldButton` "Hora de la notificación" sigue mostrando `_time.format(context)`.
4. Formato **24 horas** en las ruedas (coherente con cómo se muestra el valor y evita el AM/PM del dial).

**Fuera de alcance:**

- Cambiar el selector de **fecha** (`showDatePicker`) — sigue igual.
- Cambiar el picker de hora en cualquier otra pantalla que no sea el form de recordatorios.
- Segundos, o precisión menor al minuto.
- Cambios en el modelo `BillReminder`, en la programación de notificaciones o en la persistencia.

---

## Modelo de datos

_Esta feature **no introduce ni modifica datos ni estado persistente.**_ Se sigue usando `TimeOfDay _time` en el estado del form y `notifyHour`/`notifyMinute` en `BillReminder`.

---

## Plan de implementación

1. **Crear el widget del selector de ruedas.** En `reminder_form.dart` (o un archivo hermano `time_wheel_picker.dart` si conviene aislarlo), agregar una función `Future<TimeOfDay?> showTimeWheelPicker(BuildContext context, TimeOfDay initial)` que abra un `showModalBottomSheet` con:
   - Fondo `context.palette.surface`, borde superior `AppRadius.modal` (igual que `showReminderForm`).
   - Título "Elegí la hora".
   - Dos ruedas (`CupertinoPicker` para hora 0-23 y minuto 0-59, o `CupertinoDatePicker` en modo `hm` con `use24hFormat: true`).
   - Botón "Listo" que hace `Navigator.pop` devolviendo el `TimeOfDay` seleccionado.
   *Verificación:* `flutter analyze` limpio; el sheet abre y desliza.

2. **Cablear `_pickTime`.** Reemplazar el cuerpo de `_pickTime` para llamar a `showTimeWheelPicker(context, _time)` y, si no es null, `setState(() => _time = picked)`. *Verificación:* elegir una hora actualiza el texto del `_FieldButton`.

3. **Import de Cupertino.** Agregar `import 'package:flutter/cupertino.dart';` si se usan los pickers de Cupertino. *Verificación:* `flutter analyze` limpio.

4. **Verificación integral.** `flutter analyze` limpio y `flutter test` verde (los tests de recordatorios existentes siguen pasando). Prueba manual: crear un recordatorio, abrir la hora, deslizar ruedas, confirmar, y ver la hora reflejada; guardar y reabrir en edición muestra la misma hora.

---

## Criterios de aceptación

- [ ] Tocar "Hora de la notificación" abre un selector de **ruedas deslizables** (hora y minuto), no el dial de reloj de Material.
- [ ] Las ruedas inician en la hora actualmente seleccionada (`_time`).
- [ ] Confirmar con "Listo" actualiza el valor mostrado en el `_FieldButton`.
- [ ] Cancelar / cerrar el sheet sin confirmar deja `_time` sin cambios.
- [ ] La hora se guarda en `notifyHour`/`notifyMinute` igual que antes; editar un recordatorio existente muestra su hora en las ruedas.
- [ ] El selector usa formato 24h y el estilo (colores/radio) del resto del form.
- [ ] `flutter analyze` sin errores y `flutter test` en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Estilo del picker | Ruedas deslizables (Cupertino) | Dial de reloj Material / teclado numérico / botones +/− | El usuario lo eligió explícitamente: "como la alarma del teléfono". |
| Presentación | `showModalBottomSheet` propio | `showTimePicker(initialEntryMode: input)` | El modo input sigue siendo Material y no da la sensación de ruedas pedida. |
| Formato | 24 horas | 12h con AM/PM | Coherente con cómo ya se muestra la hora y más simple, sin columna AM/PM. |

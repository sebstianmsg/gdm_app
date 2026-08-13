# 16 — Recordatorios de facturas + botón PAGO → gasto automático

> **Estado:** Implementado
> **Dependencias:** spec 01 (Supabase directo, `schema.sql`, RLS por `user_id`, `expenses`, categoría "Otros"), spec 12 (columna `icon`, `resolveCategoryIcon`, carrusel de íconos, `formatMoney`), spec 14 (`HomeCarousel`: la **card 3 "Próximamente"** es el hueco que ocupa esta feature; `selectedMonthProvider`, patrón `expense_form.dart`), spec 15 (`displayCategoryColor`, `context.palette`)
> **Fecha:** 2026-08-09
> **Objetivo (una frase):** Reemplazar el placeholder "Próximamente" de la **card 3** por una lista de **recordatorios de facturas a pagar** (servicio/tarjeta/deuda) que disparan una **notificación local del sistema Android** en la fecha de inicio a una hora elegida —con opción de hacerla **persistente (no se descarta deslizando)** y de **repetir todos los meses**—, y un botón verde **PAGO** que, al tocarse, crea automáticamente el gasto en la categoría preelegida (alimentando el donut/TOTAL DEL MES) y archiva el recordatorio hasta el próximo ciclo.

---

## Alcance

**Incluye:**

1. **Card 3 = lista de recordatorios** (reemplaza el placeholder "Próximamente" de `HomeCarousel`, mismo alto fijo):
   - Encabezado con título (ej. "Recordatorios") y un botón **`+`** para crear uno nuevo.
   - **Lista scrolleable interna** (dentro del alto fijo, igual que la card 2) con los recordatorios del usuario, cada uno mostrando: ícono/etiqueta del tipo, nombre, monto (`formatMoney`), fecha de inicio (día del mes), vencimiento informativo, y el botón **PAGO**.
   - Estado vacío cuando no hay recordatorios.

2. **Formulario de recordatorio** (`reminder_form.dart`, patrón de `expense_form.dart`), que se abre al tocar `+` o al tocar un recordatorio existente para **editar/borrar**. Campos:
   - **Nombre** (descripción; será la descripción del gasto).
   - **Tipo:** servicio / tarjeta / deuda (solo etiqueta + ícono; no cambia comportamiento).
   - **Monto** (> 0).
   - **Categoría** de la app (elegida de las categorías existentes; con la que se creará el gasto).
   - **Fecha de inicio** (día en que aparece la notificación) y **fecha de vencimiento** (informativa).
   - **Hora** de la notificación (hora local del dispositivo).
   - **Toggle "Notificación persistente"** (si está ON, no se descarta deslizando; queda fija hasta que se toque PAGO).
   - **Toggle "Repetir todos los meses"**.

3. **Notificaciones locales del sistema Android** (`flutter_local_notifications`):
   - Se programa **una** notificación en la fecha de inicio a la hora elegida.
   - `ongoing`/`autoCancel` según el toggle de persistencia.
   - Solicitud del **permiso de notificaciones** (Android 13+) y de **alarmas exactas** (Android 12+).
   - **Re-programación al abrir la app** de las notificaciones pendientes (Supabase es la fuente de verdad; Android borra las notificaciones al reiniciar).

4. **Botón PAGO** (verde, letras blancas): al tocarlo crea un `expense` con `{ description = nombre, amount = monto, date = hoy, category = categoría elegida }`, cancela/descarta la notificación asociada y marca el recordatorio como **pagado en el ciclo actual**.

5. **Ciclo mensual:**
   - Tras PAGO, el recordatorio queda visible en la card 3 con estado **"Pagado"** y en color **apagado** hasta que llegue el próximo ciclo.
   - Si **"Repetir todos los meses"** está ON: al comenzar el próximo ciclo (siguiente mes) el recordatorio vuelve a estado activo, se re-programa su notificación conservando el **día del mes** (si el día no existe, **último día del mes**) y el **mismo monto** por defecto (editable antes de pagar).
   - Si está OFF: tras el PAGO el recordatorio no se reprograma (queda pagado / se puede borrar).

**No incluye:**

- **iOS / notificaciones en otras plataformas:** el foco es Android (coherente con el README).
- **Recurrencia distinta a mensual** (semanal, quincenal, anual).
- **Múltiples notificaciones por ciclo / re-avisos diarios:** es **una sola** notificación en la fecha de inicio; el vencimiento es solo informativo.
- **Auto-marcar como pagado:** el PAGO es siempre **manual**.
- **Editar el monto del gasto ya creado** desde el recordatorio (se edita, si hace falta, en el movimiento personal como cualquier gasto).
- **Notificaciones para gastos compartidos** (card 2) ni ninguna relación con `partnerships`.
- **Categorías nuevas o "sin categoría":** el recordatorio exige una categoría existente (si el usuario no tiene, usa "Otros").
- **Historial de pagos del recordatorio** (quién/cuándo pagó cada mes): solo el estado del ciclo actual.
- **Snooze / posponer** la notificación.

---

## Modelo de datos

Una tabla nueva en Supabase (`bill_reminders`) como fuente de verdad; las notificaciones locales son un reflejo device-local que se re-programa al abrir la app. **No se toca** `expenses` ni `categories` (el PAGO crea un `expense` normal por la capa existente).

### Tabla `public.bill_reminders`

| Columna | Tipo | Null | Notas |
|---|---|---|---|
| `id` | uuid PK | — | `default gen_random_uuid()` |
| `user_id` | uuid | NOT NULL | `references auth.users(id) on delete cascade`; RLS `auth.uid() = user_id` |
| `name` | text | NOT NULL | Descripción; será la `description` del gasto |
| `kind` | text | NOT NULL | `check (kind in ('service','card','debt'))` — solo etiqueta/ícono |
| `amount` | numeric(12,2) | NOT NULL | `check (amount > 0)`; monto por defecto del gasto |
| `category_id` | uuid | NOT NULL | `references public.categories(id)`; categoría con la que se crea el gasto |
| `start_day` | int | NOT NULL | `check (start_day between 1 and 31)`; **día del mes** en que aparece la notificación |
| `due_day` | int | NOT NULL | `check (due_day between 1 and 31)`; día del mes de vencimiento (informativo) |
| `notify_hour` | int | NOT NULL | `check (notify_hour between 0 and 23)` |
| `notify_minute` | int | NOT NULL | `check (notify_minute between 0 and 59)` |
| `persistent` | boolean | NOT NULL | `default false`; ON = notificación no descartable (`ongoing`) |
| `repeat_monthly` | boolean | NOT NULL | `default true` |
| `paid_cycle` | text | NULL | Ciclo pagado en formato `'YYYY-MM'`; si == ciclo actual → estado "Pagado (apagado)". `null` = nunca pagado |
| `active` | boolean | NOT NULL | `default true`; `false` cuando `repeat_monthly=false` y ya se pagó (no se reprograma) |
| `created_at` | timestamptz | NOT NULL | `default now()` |
| `updated_at` | timestamptz | NOT NULL | `default now()` |

- `create index bill_reminders_user_idx on public.bill_reminders (user_id);`

**Decisiones de modelado:**

- Se guardan **día del mes** (`start_day`/`due_day`) en vez de fechas absolutas, porque la recurrencia mensual conserva el día. La fecha concreta del ciclo se calcula en Dart (si el día no existe en el mes → último día del mes). En el formulario el usuario elige una fecha completa; se persiste solo el día.
- El **estado "pagado"** se deriva comparando `paid_cycle` con el ciclo actual (`YYYY-MM` del `selectedMonthProvider`/mes real), no se guarda un booleano suelto que haya que resetear.

### Modelo Dart

```dart
enum ReminderKind { service, card, debt }

class BillReminder {
  const BillReminder({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.categoryId,
    required this.startDay,
    required this.dueDay,
    required this.notifyHour,
    required this.notifyMinute,
    required this.persistent,
    required this.repeatMonthly,
    required this.paidCycle,
    required this.active,
  });

  final String id, name, categoryId;
  final ReminderKind kind;
  final double amount;
  final int startDay, dueDay, notifyHour, notifyMinute;
  final bool persistent, repeatMonthly, active;
  final String? paidCycle;              // 'YYYY-MM' o null

  bool isPaidForCycle(String cycle) => paidCycle == cycle;

  /// Fecha concreta de inicio para un mes dado, clamp al último día del mes.
  DateTime startDateFor(int year, int month) { /* clamp de startDay */ }
}
```

Más un `notificationId` estable derivado del `id` (para programar/cancelar en `flutter_local_notifications`).

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Migración SQL nueva** (`supabase/migrations/16_bill_reminders.sql`): tabla `bill_reminders` con constraints, índice, RLS + policies `auth.uid() = user_id` (select/insert/update/delete). *Verificación:* corre limpia sobre la DB; un usuario puede crear/leer solo sus recordatorios; otro usuario no los ve (RLS).

2. **Actualizar `supabase/schema.sql`** (consolidado) con la tabla, constraints, índice y policies del paso 1. *Verificación:* correr el schema sobre DB limpia crea `bill_reminders`; lo existente queda intacto.

3. **Modelo Dart** (`BillReminder`, `ReminderKind`) con `fromJson`/`toJson`, `isPaidForCycle`, `startDateFor` (clamp al último día del mes) y `notificationId`. *Verificación:* `flutter analyze` limpio; tests de mapeo `snake_case↔camelCase`, de `startDateFor` (día 31 en meses cortos, febrero) y de `isPaidForCycle`.

4. **Capa de datos** (`lib/data/bill_reminders_data.dart`) + provider en `core_providers.dart`: `list()`, `create()`, `update()`, `delete()`, `markPaid(id, cycle)` (setea `paid_cycle`; si `!repeat_monthly` → `active=false`), `rollToNewCycle()` (limpia `paid_cycle` de los `repeat_monthly` cuyo `paid_cycle` es un ciclo anterior). *Verificación:* interfaces mockeables; `flutter analyze` limpio; tests de la capa con doble inyectado.

5. **Providers Riverpod** (`lib/features/reminders/`): `billRemindersProvider` (`AsyncNotifier<List<BillReminder>>`) y un derivado que ordena/clasifica activos vs. pagados-del-ciclo. Lógica pura de "ciclo actual" (`YYYY-MM`) testeada. *Verificación:* `flutter test` verde para la clasificación (activo, pagado-este-ciclo, inactivo).

6. **Servicio de notificaciones locales** (`lib/services/reminder_notifications.dart`) sobre `flutter_local_notifications` + `timezone`: inicialización, solicitud de **permiso de notificaciones** (Android 13+) y **alarmas exactas** (Android 12+), `schedule(reminder)` (zonedSchedule en `startDateFor` a `notify_hour:notify_minute`, `ongoing=persistent`, `autoCancel=!persistent`), `cancel(reminder)`. Config Android: `AndroidManifest.xml` (permisos `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`, receivers de boot/reschedule del plugin), canal de notificación. *Verificación manual:* se agenda una notificación a 1–2 min; aparece a la hora; con `persistent` ON no se descarta al deslizar; con OFF sí.

7. **Re-programación al abrir la app.** En el arranque (tras login, donde ya se cargan datos): leer `bill_reminders` activos no pagados del ciclo y `schedule()` los pendientes; cancelar los que ya no correspondan. *Verificación manual:* reiniciar el dispositivo/app re-crea las notificaciones pendientes.

8. **Roll de ciclo.** Al abrir la app (o al cambiar de mes real), ejecutar `rollToNewCycle()` para reactivar los `repeat_monthly` cuyo `paid_cycle` quedó en un mes anterior, reprogramando su notificación con el mismo monto/día. *Verificación manual:* un recordatorio pagado el mes pasado aparece activo de nuevo este mes con su notificación reprogramada.

9. **Card 3 — lista de recordatorios** (`lib/features/reminders/reminders_card.dart`): reemplaza el placeholder "Próximamente" en `HomeCarousel`; encabezado + `+`, lista scrolleable interna dentro del alto fijo, estado vacío, y cada fila con ícono del tipo, nombre, monto, día de inicio, vencimiento y botón **PAGO** (verde, texto blanco). Los recordatorios **pagados del ciclo** se muestran en color apagado con etiqueta "Pagado". *Verificación manual:* la card 3 lista los recordatorios; scroll interno convive con el swipe del carrusel; el estado vacío se ve bien; tema claro/oscuro.

10. **Formulario de alta/edición/borrado** (`lib/features/reminders/reminder_form.dart`): nombre, tipo (servicio/tarjeta/deuda), monto, **selector de categoría** (categorías existentes), fecha de inicio, fecha de vencimiento, hora, toggle "Notificación persistente", toggle "Repetir todos los meses". Al guardar: persiste y (re)programa la notificación; al borrar: cancela la notificación. *Verificación manual:* crear/editar/borrar refleja al instante y persiste; la notificación se reprograma según los cambios.

11. **Acción PAGO.** Al tocar PAGO: crear el `expense` `{ description=name, amount, date=hoy, categoryId }` vía la capa de `expenses` existente, `markPaid(id, cicloActual)`, cancelar la notificación, y refrescar donut/TOTAL DEL MES y la card 3. *Verificación manual:* tras PAGO el gasto aparece en el donut, la leyenda y los movimientos personales del mes; el recordatorio queda "Pagado" apagado; la notificación desaparece.

12. **Repaso e integración.** `flutter analyze` limpio, `flutter test` verde; recorrido en tema claro/oscuro; permisos denegados manejados con mensaje claro; confirmar que el gesto del carrusel, el scroll del home y el scroll interno de la card 3 conviven. *Verificación:* suite verde, sin regresiones en cards 1 y 2.

---

## Criterios de aceptación

**Card 3 y formulario:**

- [ ] La card 3 del carrusel ya **no** muestra "Próximamente": muestra el título, un botón `+` y la **lista scrolleable interna** de recordatorios (o el estado vacío), dentro del mismo alto fijo; el swipe del carrusel y los scrolls conviven.
- [ ] Desde `+` se abre un formulario con: nombre, tipo (servicio/tarjeta/deuda), monto, categoría (de las existentes), fecha de inicio, fecha de vencimiento, hora, toggle "Notificación persistente" y toggle "Repetir todos los meses".
- [ ] Se puede **crear, editar y borrar** un recordatorio; los cambios persisten en `bill_reminders` y se reflejan al instante.
- [ ] El monto exige `> 0` y la categoría es obligatoria.

**Notificaciones (Android):**

- [ ] Se agenda **una** notificación local en la fecha de inicio (día del mes) a la hora elegida (hora local del dispositivo).
- [ ] Con "Notificación persistente" **ON**, la notificación **no** se descarta al deslizar; con **OFF**, sí.
- [ ] La app solicita el permiso de notificaciones (Android 13+) y de alarmas exactas (Android 12+); si se deniegan, se informa con un mensaje claro y la app no rompe.
- [ ] Al abrir la app se **re-programan** las notificaciones pendientes (sobreviven al reinicio del dispositivo); Supabase es la fuente de verdad.
- [ ] El vencimiento es **informativo**: no genera una segunda notificación.

**PAGO y ciclo:**

- [ ] El botón **PAGO** es verde con texto blanco.
- [ ] Al tocar PAGO se crea un `expense` con `{ description=nombre, amount=monto, date=hoy, categoría=la elegida }`, visible en el **donut**, la **leyenda**, el **TOTAL DEL MES** y los **movimientos personales**.
- [ ] Tras PAGO, la notificación asociada desaparece y el recordatorio queda marcado como **"Pagado"** y en color **apagado** hasta el próximo ciclo.
- [ ] Con "Repetir todos los meses" **ON**, al comenzar el nuevo ciclo el recordatorio vuelve a estado activo, con su notificación reprogramada (mismo día del mes, con **último día del mes** si el día no existe) y el **mismo monto** por defecto.
- [ ] Con "Repetir todos los meses" **OFF**, tras el PAGO el recordatorio **no** se reprograma.
- [ ] El PAGO es siempre **manual** (nada se marca pagado automáticamente).

**Aislamiento y calidad:**

- [ ] Ningún usuario ve recordatorios de otro (RLS `auth.uid() = user_id`); `schema.sql` consolidado refleja la tabla.
- [ ] Los recordatorios **no** afectan las cards 1 y 2 salvo por el gasto que crea el PAGO (que es un `expense` personal normal).
- [ ] Funciona en tema claro y oscuro; `flutter analyze` sin errores y `flutter test` en verde (incluye tests de mapeo, `startDateFor` y clasificación por ciclo).

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Tipo de aviso | **Notificación local del sistema Android** (`flutter_local_notifications`) | Solo aviso dentro de la app | El pedido de "quitar deslizando" y "persistente" es literalmente el comportamiento nativo; solo el SO lo ofrece con la app cerrada. |
| Frecuencia del aviso | **Una** notificación en la fecha de inicio | Re-avisos diarios hasta el vencimiento | El usuario lo definió así; el vencimiento queda como dato informativo, sin ruido de notificaciones repetidas. |
| Persistencia | **Toggle por recordatorio** (`ongoing`/`autoCancel`) | Global para toda la app | Cada factura decide si su aviso es fijo o descartable; más flexible. |
| Ciclo tras PAGO | **Archivar y reprogramar el próximo mes** (si "Repetir") | Borrar el recordatorio al pagar | Evita recrear la factura mensual a mano; el estado "Pagado apagado" comunica que ya se cumplió el ciclo. |
| Estado "pagado" | **Derivado de `paid_cycle` (`YYYY-MM`) vs. ciclo actual** | Booleano `is_paid` que hay que resetear cada mes | No requiere un job de reset; el estado se calcula solo al pasar de mes. |
| Fechas | **Guardar día del mes (`start_day`/`due_day`)** | Guardar fechas absolutas | La recurrencia mensual conserva el día; la fecha concreta se calcula por ciclo (clamp al último día del mes). |
| Día inexistente | **Último día del mes** (clamp) | Saltar el mes / mover al 1° del siguiente | Comportamiento intuitivo para "el 31" en meses cortos; nunca se pierde el aviso. |
| Monto al repetir | **Mismo monto por defecto, editable antes de pagar** | Pedir el monto cada mes | Menos fricción; el caso común es monto estable, y se puede ajustar si cambió. |
| Fuente de verdad | **Supabase + reprogramar al abrir la app** | Solo notificaciones locales (device) | Android borra las notificaciones al reiniciar; la tabla garantiza que sobrevivan y se sincronicen entre reinstalaciones. |
| Tipo (servicio/tarjeta/deuda) | **Solo etiqueta + ícono** | Comportamiento distinto por tipo | Mantiene el MVP simple; el tipo es informativo/visual. |
| Categoría | **Obligatoria, de las categorías existentes** | Categoría propia de recordatorios / sin categoría | El gasto del PAGO debe entrar al donut con una categoría real; reusa el modelo actual (default "Otros"). |
| PAGO | **Manual** (crea `expense` de fecha = hoy) | Auto-marcar pagado en la fecha de vencimiento | El usuario controla cuándo efectivamente pagó; evita registrar gastos que no ocurrieron. |
| Ubicación | **Card 3 del carrusel + formulario en modal aparte** | Pantalla dedicada fuera del home | Coherente con el diseño del carrusel (spec 14): el `+` abre el modal, la lista vive en la card. |
| Plataforma | **Android** | iOS/multiplataforma en este spec | El README fija el foco en Android; las notificaciones iOS quedan para otro spec. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| **Permisos de alarma exacta** (Android 12+): Google restringe `SCHEDULE_EXACT_ALARM`; sin él la notificación puede llegar tarde o no dispararse. | Alto | Solicitar el permiso explícitamente; si se deniega, degradar a alarma **inexacta** avisando al usuario que el horario puede variar. Documentar el requisito en el README. |
| **Permiso de notificaciones denegado** (Android 13+): el recordatorio se guarda pero nunca notifica. | Alto | Pedir `POST_NOTIFICATIONS` al crear el primer recordatorio; si se deniega, mostrar aviso claro y un acceso a Ajustes. La lista en la card 3 sigue funcionando como respaldo visual. |
| **Notificaciones borradas al reiniciar el dispositivo.** | Medio | Reprogramación al abrir la app (paso 7) + receiver de boot del plugin; Supabase como fuente de verdad. |
| **Doble PAGO / doble gasto** si el usuario toca PAGO dos veces o en dos dispositivos. | Medio | `markPaid` setea `paid_cycle` del ciclo actual; la UI deshabilita PAGO cuando `isPaidForCycle(cicloActual)`; el gasto se crea una sola vez por ciclo. |
| **Notificación "persistente" (`ongoing`) que el usuario no puede quitar** ni pagando (si falla el cancel). | Medio | El PAGO cancela por `notificationId` estable; además, borrar/editar el recordatorio cancela la notificación. Probar explícitamente el ciclo crear→persistente→PAGO→desaparece. |
| **Clamp de fecha mal resuelto** (día 31, febrero, años bisiestos) → notificación en fecha equivocada. | Medio | `startDateFor` con clamp al último día del mes, cubierto por tests unitarios (paso 3). |
| **Roll de ciclo no se ejecuta** si el usuario no abre la app al cambiar de mes → el recordatorio no reaparece a tiempo. | Bajo | Se ejecuta al abrir la app y al detectar cambio de mes real; aceptable porque la notificación se programa al abrir, y el usuario suele abrir la app para pagar. |
| **Desfase de zona horaria** al viajar o cambiar la hora del sistema. | Bajo | Uso de `timezone`/hora local del dispositivo; reprogramación al abrir la app recalcula sobre la TZ vigente. |
| **Gasto creado con categoría borrada** entre la creación del recordatorio y el PAGO. | Bajo | `category_id` con FK; si la categoría se borró, `delete_category` (spec 01) ya reasigna a "Otros"; el PAGO usa la categoría vigente. |
| **La card 3 con muchos recordatorios** puede apretar el alto fijo del carrusel. | Bajo | Lista con scroll interno dentro del alto fijo (igual que la card 2, spec 14). |

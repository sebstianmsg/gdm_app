# 14 — Carrusel de cards + gastos compartidos

> **Estado:** Implementado
> **Dependencias:** spec 01 (Supabase directo, `schema.sql`, RLS por `user_id`, trigger `handle_new_user`), spec 04 (donut grande/responsive, `DonutCard`), spec 08 (auth email/Google, `user_metadata.full_name`), spec 11 (`AppPalette`/tema por contexto, `context.palette`), spec 12 (dots + `PageView` del carrusel de íconos como referencia visual; `formatMoney`)
> **Fecha:** 2026-08-01
> **Objetivo (una frase):** Convertir la card del donut en un **carrusel deslizable horizontal de 3 cards de alto fijo** con **3 puntitos indicadores debajo** (card 1 = donut actual sin cambios; card 2 = **gastos compartidos** completos con otra persona vía código de invitación, balance informativo por mes y lista scrolleable interna; card 3 = placeholder "Próximamente"), dejando **intactos** la MovementsCard, el total personal y el donut.

---

## Alcance

**Incluye:**

1. **Carrusel de 3 cards (`HomeCarousel`)** que reemplaza a la actual `DonutCard` en `home_screen.dart`:
   - `PageView` horizontal de **alto fijo** (el alto natural de la card del donut, donut + leyenda). Las cards 2 y 3 se ajustan a ese mismo alto.
   - **3 puntitos indicadores debajo del carrusel**, fuera de las cards (entre el carrusel y la `MovementsCard`), con el dot activo resaltado (`context.palette`), estilo consistente con los dots del carrusel de íconos (spec 12).
   - **Solo desliza la zona del donut.** La `MovementsCard`, el `_MonthCard` (total personal) y el header quedan fijos, igual que hoy.
   - **Card 1 = donut actual**, sin cambios funcionales (`DonutCard` tal cual).
   - **Card 3 = placeholder "Próximamente"** (ícono/texto tenue centrado). Su contenido real queda para un spec futuro.

2. **Vínculo entre dos usuarios (`partnerships`) por código de invitación** (card 2):
   - Tablas `partner_invites` (código efímero) y `partnerships` (vínculo entre dos `user_id`, con **soft-unlink** vía `unlinked_at` para conservar el histórico).
   - Flujo: **Generar código** → la otra persona **Ingresa código** → RPC `accept_partner_invite` crea el `partnership` y consume el invite.
   - **Snapshot del nombre** de cada miembro (de `user_metadata.full_name` al vincular).

3. **Gastos compartidos (`shared_expenses`)** con CRUD completo:
   - Tabla propia con `partnership_id`, `description`, `amount`, `date`, `paid_by`, `created_by`.
   - RLS: solo los dos miembros del `partnership` pueden leer/crear/editar/borrar (helper `is_partner_member`).
   - Filtrado por mes (reusa `selectedMonthProvider`).

4. **Contenido de la card 2 (alto fijo, lista scrolleable interna):**
   - **Sin vínculo:** estado vacío con dos acciones — *Generar código* e *Ingresar código*.
   - **Con vínculo:** encabezado "Compartido con {nombre}", **TOTAL COMPARTIDO del mes**, **balance informativo** ("Vos $X · {nombre} $Y · Diferencia $Z"), y **lista scrolleable interna** de movimientos compartidos del mes (mostrando quién pagó) con botón `+` para agregar.
   - **Form de gasto compartido** (`shared_expense_form.dart`, patrón de `expense_form.dart`): descripción, monto, fecha y **toggle "¿Quién pagó?" (Vos / {nombre})**.

5. **Gestión del vínculo** (menú de la card 2): **Ver código pendiente** (si hay), **Desvincular** (con confirmación; soft-unlink) y **Ver histórico archivado** (gastos de vínculos ya desvinculados).

**No incluye:**

- **Deudas, "saldar", recordatorios o notificaciones.** No es Splitwise: el balance es meramente informativo.
- **Divisiones por porcentaje / partes desiguales / ítems por persona.** Solo "quién pagó" el gasto completo.
- **Grupos de más de 2 personas.** Solo vínculo 1-a-1.
- **Mezclar compartidos con el control personal** (donut, TOTAL DEL MES, movimientos personales): quedan siempre separados.
- **Categorías en los gastos compartidos** (el MVP no categoriza).
- **Acumulado histórico** del balance: solo por mes.
- **Contenido real de la card 3:** solo placeholder "Próximamente"; se define en un spec futuro.
- **Altura adaptable por card:** el carrusel usa **alto fijo** (el del donut); no se mide cada página.
- **Que la MovementsCard o el resto del home entren en el carrusel:** solo desliza la zona del donut.
- Chat, adjuntar comprobantes/fotos, histórico de "quién editó".

---

## Modelo de datos

Tres tablas nuevas y un helper de pertenencia. **No se toca** `expenses`, `categories`, ni el cálculo de totales personales. El carrusel (card 1 y 3) **no introduce datos nuevos**: es solo UI.

### Tabla `public.partnerships`

Vínculo entre dos usuarios. Se **normaliza el orden** (`user_low < user_high`) para que el par sea único sin importar quién invitó. **Soft-unlink** vía `unlinked_at` para conservar el histórico de gastos al desvincular.

| Columna | Tipo | Null | Notas |
|---|---|---|---|
| `id` | uuid PK | — | `default gen_random_uuid()` |
| `user_low` | uuid | NOT NULL | `references auth.users(id) on delete cascade`; siempre el uuid menor del par |
| `user_high` | uuid | NOT NULL | `references auth.users(id) on delete cascade`; siempre el uuid mayor |
| `user_low_name` | text | NOT NULL | Snapshot del nombre de `user_low` al vincular |
| `user_high_name` | text | NOT NULL | Snapshot del nombre de `user_high` al vincular |
| `created_at` | timestamptz | NOT NULL | `default now()` |
| `unlinked_at` | timestamptz | NULL | Se setea al desvincular. `null` = vínculo activo; no-nulo = archivado |

- `constraint partnerships_order check (user_low < user_high)`
- **MVP 1-a-1 (solo vínculos activos):** índices únicos parciales que impiden **dos vínculos activos** por usuario, pero permiten re-vincularse tras desvincular:
  `create unique index partnerships_one_active_low on public.partnerships (user_low) where unlinked_at is null;`
  `create unique index partnerships_one_active_high on public.partnerships (user_high) where unlinked_at is null;`

### Tabla `public.partner_invites`

Código efímero de invitación (uno pendiente por invitador).

| Columna | Tipo | Null | Notas |
|---|---|---|---|
| `id` | uuid PK | — | `default gen_random_uuid()` |
| `code` | text | NOT NULL | Código corto legible, `unique` (ej. 8 chars A–Z/2–9, sin ambiguos) |
| `inviter_id` | uuid | NOT NULL | `references auth.users(id) on delete cascade` |
| `inviter_name` | text | NOT NULL | Snapshot del nombre del invitador |
| `created_at` | timestamptz | NOT NULL | `default now()` |
| `expires_at` | timestamptz | NOT NULL | `default now() + interval '7 days'` |
| `consumed_at` | timestamptz | NULL | Se setea al aceptar; un invite consumido no se reutiliza |

- `create unique index partner_invites_one_pending_per_inviter on public.partner_invites (inviter_id) where consumed_at is null;`

### Tabla `public.shared_expenses`

| Columna | Tipo | Null | Notas |
|---|---|---|---|
| `id` | uuid PK | — | `default gen_random_uuid()` |
| `partnership_id` | uuid | NOT NULL | `references public.partnerships(id) on delete cascade` (el partnership no se borra al desvincular, solo se marca `unlinked_at`, así que los gastos se conservan) |
| `description` | text | NOT NULL | |
| `amount` | numeric(12,2) | NOT NULL | `check (amount > 0)` |
| `date` | date | NOT NULL | |
| `paid_by` | uuid | NOT NULL | `references auth.users(id)`; debe ser uno de los dos miembros del vínculo |
| `created_by` | uuid | NOT NULL | `references auth.users(id)`; quién cargó el gasto |
| `created_at` | timestamptz | NOT NULL | `default now()` |

- `create index shared_expenses_partnership_date_idx on public.shared_expenses (partnership_id, date);`

### Helper de pertenencia (para RLS)

```sql
create or replace function public.is_partner_member(p_partnership_id uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (
    select 1 from public.partnerships p
    where p.id = p_partnership_id
      and auth.uid() in (p.user_low, p.user_high)
  );
$$;
```

> Nota: `is_partner_member` **no** filtra por `unlinked_at`, para que ambos miembros sigan pudiendo leer los gastos **archivados** de un vínculo desvinculado (histórico). El alta de nuevos gastos sobre un vínculo archivado se restringe en la policy de INSERT de `shared_expenses` (ver Plan de implementación).

### Modelos Dart

```dart
class Partnership {
  const Partnership({
    required this.id,
    required this.userLow, required this.userHigh,
    required this.userLowName, required this.userHighName,
    required this.unlinkedAt,
  });
  final String id;
  final String userLow, userHigh, userLowName, userHighName;
  final DateTime? unlinkedAt;               // null = activo
  bool get isActive => unlinkedAt == null;

  /// Nombre de la otra persona respecto de [me].
  String partnerName(String me) => me == userLow ? userHighName : userLowName;
}

class SharedExpense {
  const SharedExpense({
    required this.id, required this.partnershipId,
    required this.description, required this.amount,
    required this.date, required this.paidBy, required this.createdBy,
  });
  final String id, partnershipId, description, paidBy, createdBy;
  final double amount;
  final DateTime date;
}
```

Más `SharedBalance` (resultado puro de `summarize`): `{ total, paidByMe, paidByPartner, partnerName }`.

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Migración SQL nueva** (`supabase/migrations/14_carrusel_gastos_compartidos.sql`): tablas `partnerships` (con `unlinked_at`), `partner_invites`, `shared_expenses`, índices (incluidos los únicos parciales `where unlinked_at is null`), helper `is_partner_member`, RPCs `create_partner_invite` y `accept_partner_invite`, RLS + policies. La policy de INSERT de `shared_expenses` valida además que el `partnership` esté **activo** (`unlinked_at is null`) y que `paid_by` sea uno de los dos miembros. *Verificación:* corre limpia sobre la DB; con dos usuarios de prueba se puede generar código, aceptarlo y crear un gasto compartido visible por ambos.

2. **Actualizar `supabase/schema.sql`** (consolidado) con todo lo del paso 1. *Verificación:* correr el schema sobre DB limpia crea las tres tablas, el helper, las RPCs y las policies; lo existente sigue intacto.

3. **Modelos Dart** (`Partnership` con `unlinkedAt`/`isActive`, `PartnerInvite`, `SharedExpense`) con `fromJson`/helpers según la convención existente. *Verificación:* `flutter analyze` limpio; tests de mapeo y de `partnerName`.

4. **Capa de datos** (`lib/data/partnerships_data.dart`, `lib/data/shared_expenses_data.dart`) + registro de providers en `core_providers.dart`. Incluye `current()` (vínculo activo), `pendingInvite()`, `createInvite()`, `acceptInvite(code)`, `unlink(id)`, `archivedExpenses(...)`, y CRUD de `shared_expenses` por mes. *Verificación:* interfaces mockeables; `flutter analyze` limpio.

5. **Providers Riverpod** (`lib/features/shared/`): `partnershipProvider` (`AsyncNotifier<Partnership?>`), `pendingInviteProvider`, `sharedExpensesProvider` (familia por `(partnershipId, month)`) y `summarize` puro con tests. *Verificación:* `flutter test` verde para `summarize` (casos: vacío, todo uno, mezcla, mes sin gastos).

6. **`HomeCarousel` — esqueleto del carrusel** (`lib/features/month/home_carousel.dart`): `PageView` horizontal de **alto fijo** (el del donut) con 3 páginas y **3 dots debajo**. Card 1 = `DonutCard` actual (movida adentro sin cambios), card 2 = placeholder temporal, card 3 = placeholder "Próximamente". Reemplaza a `DonutCard` en `home_screen.dart`. *Verificación manual:* se desliza entre las 3 cards, los dots reflejan la página, la `MovementsCard` y el total personal no cambian; el donut se ve igual que antes.

7. **Card 2 — estado vacío** (Generar / Ingresar código, modales). *Verificación manual:* dos cuentas se vinculan de punta a punta; errores (`invite_invalid`, `invite_self`, ya vinculado) muestran mensaje claro.

8. **Card 2 — estado vinculado** (encabezado + TOTAL COMPARTIDO + balance + **lista scrolleable interna** dentro del alto fijo). *Verificación manual:* el total y el balance reflejan los gastos del mes; la lista scrollea dentro de la card sin romper el swipe horizontal; navegar de mes filtra bien y **no** afecta el donut/total personal.

9. **Form de alta/edición/borrado de gasto compartido** (`shared_expense_form.dart`) con selector "¿Quién pagó?". *Verificación manual:* crear/editar/borrar refleja al instante y persiste; ambos miembros ven los cambios.

10. **Gestión del vínculo:** menú con **Ver código pendiente**, **Desvincular** (confirmación, soft-unlink → `unlinked_at`) y **Ver histórico archivado** (gastos de vínculos desvinculados). *Verificación manual:* desvincular vuelve la card al estado vacío conservando los gastos; el histórico archivado los muestra en solo-lectura.

11. **Card 3 — placeholder "Próximamente"** definitivo (ícono/texto tenue centrado, mismo alto fijo). *Verificación manual:* la card 3 muestra el placeholder centrado y no rompe el layout.

12. **Repaso e integración.** `flutter analyze` limpio, `flutter test` verde, recorrido en tema claro y oscuro; confirmar aislamiento total del control personal y que el gesto horizontal del carrusel convive con el scroll vertical del `ListView` del home y el scroll interno de la card 2. *Verificación:* suite verde y sin regresiones.

---

## Criterios de aceptación

**Carrusel (UI):**

- [ ] La zona del donut es un **carrusel horizontal de 3 cards de alto fijo** (el alto del donut); la `MovementsCard`, el `_MonthCard` (TOTAL DEL MES) y el header quedan **fijos** e iguales que antes.
- [ ] Hay **3 puntitos indicadores debajo del carrusel** (fuera de las cards, entre el carrusel y la `MovementsCard`); el dot activo se resalta con `context.palette` y refleja la página visible.
- [ ] **Card 1** muestra el donut y la leyenda exactamente como hoy (sin regresiones funcionales ni visuales).
- [ ] **Card 3** muestra un placeholder "Próximamente" (ícono/texto tenue centrado) en el mismo alto fijo.
- [ ] El gesto horizontal del carrusel convive con el scroll vertical del home y con el scroll interno de la card 2 (ninguno bloquea al otro).

**Vínculo y datos:**

- [ ] Existen `partnerships` (con `unlinked_at`), `partner_invites` y `shared_expenses` con sus constraints, índices y RLS; `schema.sql` consolidado las refleja.
- [ ] Un usuario puede **generar un código**; otro puede **ingresarlo y aceptar**, creando el vínculo. El invite queda consumido y no se reutiliza.
- [ ] No se puede aceptar el **propio** código, ni un código **vencido/usado**, ni crear un **segundo vínculo activo** (mensaje claro en cada caso).
- [ ] Ningún usuario puede leer invites, vínculos ni gastos compartidos ajenos (verificado por RLS: solo miembros).

**Gastos compartidos (card 2):**

- [ ] Con vínculo activo, la card 2 muestra: nombre de la otra persona, **TOTAL COMPARTIDO del mes**, **balance informativo** ("Vos $X · {nombre} $Y · Diferencia $Z") y una **lista scrolleable interna** de los movimientos del mes indicando quién pagó.
- [ ] Se puede **crear/editar/borrar** un gasto compartido eligiendo **quién pagó** (Vos / {nombre}); ambos miembros ven los cambios.
- [ ] Los gastos compartidos **no** aparecen en el donut, ni en el "TOTAL DEL MES", ni en los movimientos personales (aislamiento total).
- [ ] El balance es **informativo y por mes**: sin "saldar", sin deudas, sin notificaciones, sin acumulado histórico.
- [ ] Se puede **ver el código pendiente** y **desvincular** (con confirmación).
- [ ] Al **desvincular**, el vínculo se marca archivado (`unlinked_at`), la card vuelve al estado vacío y los gastos compartidos **se conservan**; existe un **histórico archivado** en solo-lectura para consultarlos.

**Calidad:**

- [ ] Funciona en tema claro y oscuro; `flutter analyze` sin errores y `flutter test` en verde (incluye tests de `summarize` y de mapeo de modelos).

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Alcance del spec | **Carrusel + gastos compartidos completo** en un solo spec | Partir en dos (carrusel primero, feature después) | El usuario lo pidió unido; el carrusel sin la card 2 real mostraría solo un placeholder. Se acepta un spec grande a cambio de entregar la feature de punta a punta. |
| Qué desliza | **Solo la zona del donut** (3 cards) | Que la MovementsCard/home entren al carrusel | Mantiene fijos el total personal y los movimientos; el carrusel es un contenedor acotado y predecible. |
| Altura del carrusel | **Alto fijo** (el del donut) | Altura adaptable por card | Simple y estable al deslizar; evita medir cada página y saltos de layout. La card 2 resuelve su contenido con scroll interno. |
| Indicador de páginas | **3 dots debajo, fuera de las cards** | Dots dentro de cada card | Consistente con el carrusel de íconos (spec 12); no compite con el contenido de cada card. |
| Contenido card 2 en alto fijo | **Balance arriba + lista scrolleable interna** | Card = resumen y lista en pantalla aparte | El usuario quiere todo en un lugar; el scroll interno entra dentro del alto fijo. |
| Card 3 | **Placeholder "Próximamente"** | Card completamente vacía | Comunica que habrá algo ahí; su contenido real se define en un spec futuro. |
| Impacto en el control personal | **Separado** (tabla y card propias) | Contar la parte propia / el gasto completo en el donut | Dos mundos que no se mezclan; el donut/total personal queda intacto. |
| Vínculo entre usuarios | **Código de invitación** | Por email / elegir de una lista | No expone emails ni la lista de usuarios; más privado y no debilita la RLS. |
| Naturaleza del balance | **Informativo, por mes** | Deudas / "saldar" / acumulado histórico | Filosofía de la app: llevar control, no gestionar deudas; coherente con el resto (por mes). |
| Cardinalidad | **1-a-1** (un vínculo activo por usuario) | Grupos de 3+ | Caso de uso (pareja); simplifica modelo, RLS y UI. |
| Reparto del gasto | **Registrar completo + "quién pagó"** | Split %/partes/ítems por persona | El balance como diferencia de aportes alcanza para "control"; el split es complejidad de Splitwise. |
| Desvincular | **Soft-unlink (`unlinked_at`) — se conservan los gastos** | Hard delete con `on delete cascade` | El usuario quiere conservar el histórico; marcar `unlinked_at` mantiene los gastos y permite re-vincularse (índices únicos parciales). |
| Nombre de la otra persona | **Snapshot en el vínculo** al enlazar | Leer `auth.users`/tabla `profiles` en runtime | La RLS no deja leer datos del otro usuario; el snapshot evita una tabla de perfiles. |
| Aceptar invite | **RPC `security definer`** | Policies de lectura abiertas sobre invites | Encapsula el cruce de datos ajenos sin abrir la tabla de invites a todos. |
| Generación del código | **Server-side (RPC)** con alfabeto no ambiguo | Generar en el cliente | Garantiza unicidad y evita colisiones; el cliente solo recibe el string. |
| Categorías en compartidos | **Sin categoría** (MVP) | Reusar categorías personales | Mantiene el MVP simple y separado; se puede sumar en otro spec. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| El swipe **horizontal** del carrusel compite con el **scroll vertical** del `ListView` del home y con el **scroll interno** de la card 2. | Medio | El `PageView` captura solo gestos horizontales; el scroll de la card 2 es vertical y acotado. Se prueba explícitamente el gesto en los pasos 6, 8 y 12. |
| El **alto fijo** del donut varía con el largo de la leyenda; las cards 2 y 3 podrían quedar apretadas o con espacio de sobra. | Medio | El carrusel toma el alto natural del donut+leyenda; la card 2 usa scroll interno para su lista y la card 3 centra su placeholder. Aceptado como parte del diseño de alto fijo. |
| **Soft-unlink** mal resuelto: un usuario no puede re-vincularse porque el índice único sigue tomando el vínculo viejo. | Medio | Índices únicos **parciales** `where unlinked_at is null`; solo el vínculo **activo** ocupa el slot. Se prueba desvincular + re-vincular. |
| `is_partner_member` no filtra `unlinked_at`, así que se podrían **crear** gastos sobre un vínculo archivado. | Medio | La policy de INSERT de `shared_expenses` valida además que el `partnership` esté **activo** (`unlinked_at is null`); el archivado queda en solo-lectura. |
| Colisión de códigos de invitación. | Bajo | Generación server-side con alfabeto no ambiguo + `unique` en `code`; reintento ante colisión. |
| Fugas por RLS (ver datos de otros). | Alto | `shared_expenses` gobernada por `is_partner_member`; invites/partnerships solo para miembros; aceptación solo por RPC. `paid_by` validado contra los miembros del vínculo. |
| El nombre snapshot queda desactualizado si la persona cambia su nombre. | Bajo | Aceptable para MVP; refrescable en un spec futuro. |
| Confusión sobre qué corre (migración vs schema). | Bajo | `14_carrusel_gastos_compartidos.sql` es para DBs existentes; `schema.sql` para DB limpia, igual que en specs previos. |
| El usuario espera que el balance "sume" al total personal. | Bajo | Copy explícito de que compartidos son aparte e informativos; separación reforzada en UI (card distinta dentro del carrusel). |
| Spec grande: riesgo de entrega parcial. | Medio | El plan deja el sistema funcional paso a paso (el carrusel con placeholders ya es entregable en el paso 6); se puede pausar entre etapas sin romper el home. |

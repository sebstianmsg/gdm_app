# Gastos compartidos (con vínculo entre dos usuarios)

> **Estado:** Draft (futuro)
> **Dependencias:** spec 01 (Supabase directo, `schema.sql`, RLS por `user_id`, trigger `handle_new_user`), spec 08 (auth email/Google, `user_metadata.full_name`), spec 11 (`AppPalette`/tema por contexto, `context.palette`), spec 12 (íconos de categoría — solo reuso visual opcional)
> **Fecha:** 2026-08-01
> **Objetivo (una frase):** Permitir que un usuario **vincule a otro mediante un código de invitación** para llevar juntos un registro de **gastos compartidos** (ej. una cena), en una **card propia separada del control personal** que muestra el total del mes, cuánto puso cada uno y un **balance meramente informativo** — sin lógica de deudas ni "saldar" al estilo Splitwise, fiel a la filosofía de la app (control de gastos).

---

## Filosofía y decisiones marco

- **Separado del control personal.** Los gastos compartidos **no** entran en el donut, ni en el "TOTAL DEL MES", ni en los movimientos personales. Viven en su propia card/sección y en su propia tabla. Son "dos mundos" que no se mezclan.
- **Vínculo por código de invitación.** Un usuario genera un código corto; el otro lo ingresa y acepta. **No** se exponen emails ni la lista de usuarios de la base (privacidad + no debilitar la RLS).
- **Balance informativo, no deuda.** El balance solo dice "vos pusiste $X, la otra persona $Y" para tener control. No hay recordatorios, ni "te debe", ni acción de saldar.
- **Vínculo 1-a-1 (MVP).** Cada usuario tiene, como mucho, **un** vínculo activo (pensado para pareja). Grupos de 3+ quedan explícitamente fuera de alcance.

---

## Alcance

**Incluye:**

1. **Vínculo entre dos usuarios (`partnerships`) por código de invitación.**
   - Tabla `partner_invites` (código efímero) y tabla `partnerships` (vínculo activo entre dos `user_id`).
   - Flujo: **Generar código** (crea invite) → la otra persona **Ingresa código** → se crea el `partnership` y el invite queda consumido.
   - Se guarda un **snapshot del nombre** de cada miembro (tomado de `user_metadata.full_name` al vincular) para poder mostrar "quién pagó" sin poder leer `auth.users` del otro.

2. **Gastos compartidos (`shared_expenses`).**
   - Tabla propia con `partnership_id`, `description`, `amount`, `date`, `paid_by` (quién pagó: uno de los dos miembros), `created_by`.
   - RLS: solo los **dos miembros** del `partnership` pueden leer/crear/editar/borrar sus gastos compartidos (helper `is_partner_member`).
   - CRUD análogo al de `expenses` personales, filtrado por mes (reusa `selectedMonthProvider`).

3. **Card de "Gastos compartidos" en el home** (debajo de `MovementsCard`):
   - **Sin vínculo:** estado vacío con dos acciones — *Generar código* y *Ingresar código*.
   - **Con vínculo:** encabezado con el nombre de la otra persona, **total compartido del mes**, **cuánto puso cada uno** y el **balance informativo** ("vos $X · {nombre} $Y · diferencia $Z"), y la lista de movimientos compartidos del mes con botón de alta.
   - Alta/edición/borrado de gasto compartido con un form propio (reusa el patrón de `expense_form.dart`): descripción, monto, fecha y **selector de quién pagó** (vos / la otra persona).

4. **Gestión del vínculo:** poder **ver el código generado** mientras esté pendiente y **desvincular** (borra el `partnership`; los gastos compartidos se conservan o se borran — ver Decisiones).

**No incluye:**

- **Deudas, "saldar", recordatorios o notificaciones** de ningún tipo (explícitamente fuera: no es Splitwise).
- **Divisiones por porcentaje / partes desiguales.** El MVP registra el gasto completo con "quién pagó"; el balance es la diferencia de lo aportado por cada uno. Reparto 60/40, ítems por persona, etc. quedan fuera.
- **Grupos de más de 2 personas.** Solo vínculo 1-a-1.
- **Mezclar compartidos con el control personal** (donut, total del mes, movimientos personales): quedan siempre separados.
- **Categorías en los gastos compartidos** (el MVP no categoriza; se puede sumar en otro spec).
- Chat, adjuntar comprobantes, fotos, o histórico de "quién editó".

---

## Modelo de datos

Tres tablas nuevas y un helper de pertenencia. **No se toca** `expenses` ni `categories` ni el cálculo de totales personales.

### Tabla `public.partnerships`

Vínculo activo entre dos usuarios. Se **normaliza el orden** (`user_low < user_high`) para que el par sea único sin importar quién invitó.

| Columna | Tipo | Null | Notas |
|---|---|---|---|
| `id` | uuid PK | — | `default gen_random_uuid()` |
| `user_low` | uuid | NOT NULL | `references auth.users(id) on delete cascade`; siempre el uuid menor del par |
| `user_high` | uuid | NOT NULL | `references auth.users(id) on delete cascade`; siempre el uuid mayor |
| `user_low_name` | text | NOT NULL | Snapshot del nombre de `user_low` al vincular |
| `user_high_name` | text | NOT NULL | Snapshot del nombre de `user_high` al vincular |
| `created_at` | timestamptz | NOT NULL | `default now()` |

- `constraint partnerships_pair_unique unique (user_low, user_high)`
- `constraint partnerships_order check (user_low < user_high)`
- **MVP 1-a-1:** índice único parcial para impedir que un usuario tenga dos vínculos:
  `create unique index partnerships_one_per_low on public.partnerships (user_low);`
  `create unique index partnerships_one_per_high on public.partnerships (user_high);`
  (Si se quisiera permitir varios vínculos por persona a futuro, se relaja quitando estos índices.)

### Tabla `public.partner_invites`

Código efímero de invitación (uno pendiente por invitador).

| Columna | Tipo | Null | Notas |
|---|---|---|---|
| `id` | uuid PK | — | `default gen_random_uuid()` |
| `code` | text | NOT NULL | Código corto legible, único (ej. 8 chars A–Z/2–9, sin caracteres ambiguos). `unique` |
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
| `partnership_id` | uuid | NOT NULL | `references public.partnerships(id) on delete cascade` |
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
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.partnerships p
    where p.id = p_partnership_id
      and auth.uid() in (p.user_low, p.user_high)
  );
$$;
```

### Modelos Dart

```dart
class Partnership {
  const Partnership({
    required this.id,
    required this.userLow,
    required this.userHigh,
    required this.userLowName,
    required this.userHighName,
  });
  final String id;
  final String userLow, userHigh, userLowName, userHighName;

  /// Nombre de la otra persona respecto de [me].
  String partnerName(String me) => me == userLow ? userHighName : userLowName;
}

class SharedExpense {
  const SharedExpense({
    required this.id,
    required this.partnershipId,
    required this.description,
    required this.amount,
    required this.date,
    required this.paidBy,
    required this.createdBy,
  });
  final String id, partnershipId, description, paidBy, createdBy;
  final double amount;
  final DateTime date;
}
```

---

## RLS + Policies

```sql
alter table public.partnerships     enable row level security;
alter table public.partner_invites  enable row level security;
alter table public.shared_expenses  enable row level security;

-- partnerships: cada miembro ve/borra su vínculo. La creación va por RPC
-- (accept_partner_invite) con security definer, así que no hace falta INSERT abierto.
create policy partnerships_member_select on public.partnerships
  for select using (auth.uid() in (user_low, user_high));
create policy partnerships_member_delete on public.partnerships
  for delete using (auth.uid() in (user_low, user_high));

-- partner_invites: el invitador ve/gestiona sus propios invites.
create policy partner_invites_owner_all on public.partner_invites
  for all using (auth.uid() = inviter_id) with check (auth.uid() = inviter_id);

-- shared_expenses: ambos miembros del vínculo tienen CRUD completo.
create policy shared_expenses_member_all on public.shared_expenses
  for all
  using (public.is_partner_member(partnership_id))
  with check (public.is_partner_member(partnership_id)
    and paid_by in (
      select user_low from public.partnerships where id = partnership_id
      union
      select user_high from public.partnerships where id = partnership_id
    ));
```

> **Aceptar invite vía RPC (`security definer`)**, porque quien acepta necesita leer un invite ajeno (por código) y escribir un `partnership` que lo referencia. Encapsularlo en una función evita abrir policies de lectura sobre invites de otros:

```sql
create or replace function public.accept_partner_invite(p_code text)
returns uuid                       -- devuelve el partnership_id creado
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite   public.partner_invites;
  v_me       uuid := auth.uid();
  v_my_name  text;
  v_low uuid; v_high uuid; v_low_name text; v_high_name text;
  v_pid uuid;
begin
  select * into v_invite from public.partner_invites
   where code = p_code and consumed_at is null and expires_at > now();
  if not found then
    raise exception 'invite_invalid';        -- código inexistente/vencido/usado
  end if;
  if v_invite.inviter_id = v_me then
    raise exception 'invite_self';           -- no podés aceptar tu propio código
  end if;

  v_my_name := coalesce(
    (select raw_user_meta_data->>'full_name' from auth.users where id = v_me),
    'Usuario');

  if v_invite.inviter_id < v_me then
    v_low := v_invite.inviter_id; v_low_name := v_invite.inviter_name;
    v_high := v_me;               v_high_name := v_my_name;
  else
    v_low := v_me;                v_low_name := v_my_name;
    v_high := v_invite.inviter_id;v_high_name := v_invite.inviter_name;
  end if;

  insert into public.partnerships (user_low, user_high, user_low_name, user_high_name)
  values (v_low, v_high, v_low_name, v_high_name)
  returning id into v_pid;       -- unique index falla si alguno ya tiene vínculo

  update public.partner_invites set consumed_at = now() where id = v_invite.id;
  return v_pid;
end;
$$;
```

Errores esperados a mapear en la UI: `invite_invalid` ("Código inválido o vencido"), `invite_self` ("Ese es tu propio código"), violación de índice único ("Vos o esa persona ya tienen un vínculo activo").

---

## Capa de datos (Dart)

`lib/data/partnerships_data.dart` (interfaz + impl Supabase):
- `Future<Partnership?> current()` — el vínculo del usuario (o `null`).
- `Future<PartnerInvite> createInvite()` — genera código (RPC o insert), devuelve el código.
- `Future<PartnerInvite?> pendingInvite()` — invite pendiente propio (para volver a mostrar el código).
- `Future<String> acceptInvite(String code)` — RPC `accept_partner_invite`, devuelve `partnership_id`; traduce errores.
- `Future<void> unlink(String partnershipId)` — borra el `partnership`.

`lib/data/shared_expenses_data.dart` — espejo de `expenses_data.dart`:
- `listForMonth(partnershipId, month)`, `create(...)`, `update(...)`, `delete(id)`.

> **Generación del código:** hacerla en el servidor (RPC `create_partner_invite` que genera el `code` con caracteres no ambiguos y lo inserta) para garantizar unicidad y evitar colisiones; el cliente solo recibe el string.

---

## Providers (Riverpod)

`lib/features/shared/partnership_provider.dart`:
- `partnershipProvider` (`AsyncNotifier<Partnership?>`) — vínculo actual; `createInvite`, `acceptInvite`, `unlink`, `refresh`.
- `pendingInviteProvider` — invite pendiente para mostrar el código.

`lib/features/shared/shared_expenses_provider.dart`:
- Familia por `(partnershipId, month)` — CRUD que refresca, análogo a `expensesProvider`.

`lib/features/shared/shared_balance.dart`:
- Función pura `SharedBalance summarize(List<SharedExpense> items, {required String me, required Partnership p})` → `{ total, paidByMe, paidByPartner, partnerName }`. **Testeable por unidad** sin UI.

---

## UI

`lib/features/shared/shared_card.dart` — se inserta en `home_screen.dart` **debajo de `MovementsCard`**, usando `ref.watch(selectedMonthProvider)` para el mismo mes que el resto.

- **Estado vacío (sin vínculo):** título "Gastos compartidos", texto breve ("Vinculá a otra persona para llevar juntos los gastos que comparten") y dos botones: **Generar código** (abre modal con el código + botón copiar) e **Ingresar código** (abre modal con input; al aceptar, refresca).
- **Estado vinculado:**
  - Encabezado: "Compartido con {nombre}" + acción de menú para **Ver código pendiente** (si hay) y **Desvincular** (con confirmación, estilo `_confirmLogout`).
  - Bloque de balance: **TOTAL COMPARTIDO** del mes + fila "Vos $X · {nombre} $Y" y "Diferencia $Z" (todo con `formatMoney`). Copy explícito de que es **informativo**.
  - Lista de movimientos compartidos del mes (reusa el estilo de `movements_card.dart`/`expense_row.dart`, mostrando quién pagó) + botón `+` para agregar.
- **Form de gasto compartido** (`shared_expense_form.dart`, patrón de `expense_form.dart`): descripción, monto, fecha y un **toggle "¿Quién pagó?" (Vos / {nombre})**.

Todo respeta `context.palette` y funciona en tema claro/oscuro (spec 11).

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Migración SQL nueva** (`supabase/migrations/14_gastos_compartidos.sql`): tablas `partnerships`, `partner_invites`, `shared_expenses`, índices, `is_partner_member`, `create_partner_invite`, `accept_partner_invite`, RLS + policies. *Verificación:* corre limpia sobre la DB; con dos usuarios de prueba se puede generar código, aceptarlo y crear un gasto compartido visible por ambos.
2. **Actualizar `supabase/schema.sql`** (consolidado) con todo lo del paso 1. *Verificación:* correr el schema sobre DB limpia crea las tres tablas, el helper y las policies; lo existente sigue intacto.
3. **Modelos Dart** (`Partnership`, `PartnerInvite`, `SharedExpense`) con `fromJson`/helpers. *Verificación:* `flutter analyze` limpio; tests de mapeo y de `partnerName`.
4. **Capa de datos** (`partnerships_data.dart`, `shared_expenses_data.dart`) + providers en `core_providers.dart`. *Verificación:* interfaces mockeables; `flutter analyze` limpio.
5. **Providers Riverpod** (`partnershipProvider`, `pendingInviteProvider`, `sharedExpensesProvider`) + `summarize` puro con tests. *Verificación:* `flutter test` verde para `summarize` (varios casos: vacío, todo uno, mezcla).
6. **Card en el home — estado vacío** (Generar / Ingresar código, modales). *Verificación manual:* dos cuentas se vinculan de punta a punta; errores (`invite_invalid`, `invite_self`, ya vinculado) muestran mensaje claro.
7. **Card en el home — estado vinculado** (balance + lista de movimientos compartidos). *Verificación manual:* el total y el balance reflejan los gastos del mes; navegar de mes filtra bien y **no** afecta el donut/total personal.
8. **Form de alta/edición/borrado de gasto compartido** con selector "¿Quién pagó?". *Verificación manual:* crear/editar/borrar refleja al instante y persiste; ambos miembros ven los cambios.
9. **Ver código pendiente + Desvincular** (con confirmación). *Verificación manual:* desvincular vuelve al estado vacío; los gastos compartidos se manejan según la Decisión elegida (conservar/borrar).
10. **Repaso e integración.** `flutter analyze` limpio, `flutter test` verde, recorrido en tema claro y oscuro; confirmar aislamiento total respecto del control personal. *Verificación:* suite verde y sin regresiones en la pantalla personal.

---

## Criterios de aceptación

- [ ] Existen `partnerships`, `partner_invites`, `shared_expenses` con sus constraints, índices y RLS; `schema.sql` consolidado las refleja.
- [ ] Un usuario puede **generar un código**; otro puede **ingresarlo y aceptar**, creando el vínculo. El invite queda consumido y no se reutiliza.
- [ ] No se puede aceptar el **propio** código, ni un código **vencido/usado**, ni crear un **segundo** vínculo (mensajes claros en cada caso).
- [ ] Ningún usuario puede leer invites, vínculos ni gastos compartidos ajenos (verificado por RLS: solo miembros).
- [ ] La card muestra, con vínculo activo: nombre de la otra persona, **total compartido del mes**, aporte de cada uno y **diferencia**, más la lista de movimientos del mes.
- [ ] Se puede **crear/editar/borrar** un gasto compartido eligiendo **quién pagó**; ambos miembros ven los cambios.
- [ ] Los gastos compartidos **no** aparecen en el donut, ni en el "TOTAL DEL MES", ni en los movimientos personales (aislamiento total).
- [ ] El balance es **informativo**: no hay "saldar", ni deudas, ni notificaciones.
- [ ] Se puede **ver el código pendiente** y **desvincular** (con confirmación).
- [ ] Funciona en tema claro y oscuro; `flutter analyze` sin errores y `flutter test` en verde (incluye tests de `summarize`).

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Impacto en el control personal | **Separado** (tabla y card propias) | Contar solo la parte propia / contar el gasto completo marcado | El usuario quiere dos mundos que no se mezclen; el donut/total personal queda intacto. |
| Vínculo entre usuarios | **Código de invitación** | Por email / elegir de una lista | No expone emails ni la lista de usuarios; más privado y no debilita la RLS. |
| Naturaleza del balance | **Informativo** (aportes + diferencia) | Deudas / "saldar" al estilo Splitwise | Filosofía de la app: llevar control, no gestionar deudas. |
| Cardinalidad | **1-a-1** (un vínculo por usuario) | Grupos de 3+ | Caso de uso (pareja); simplifica modelo, RLS y UI. Relajable a futuro quitando los índices únicos. |
| Reparto del gasto | **Registrar completo + "quién pagó"** | Split %/partes/ítems por persona | El balance como diferencia de aportes alcanza para "control"; el split es complejidad de Splitwise. |
| Nombre de la otra persona | **Snapshot en el vínculo** al enlazar | Leer `auth.users`/tabla `profiles` en runtime | La RLS no deja leer datos del otro usuario; el snapshot evita una tabla de perfiles. |
| Aceptar invite | **RPC `security definer`** | Policies de lectura abiertas sobre invites | Encapsula el cruce de datos ajenos sin abrir la tabla de invites a todos. |
| Categorías en compartidos | **Sin categoría** (MVP) | Reusar categorías personales | Mantiene el MVP simple y separado; se puede sumar en otro spec. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Colisión de códigos de invitación. | Bajo | Generación server-side con alfabeto no ambiguo + `unique` en `code`; reintento ante colisión. |
| Un usuario intenta dos vínculos (pareja + otro). | Medio | Índices únicos parciales por `user_low`/`user_high`; `accept_partner_invite` falla claro y la UI lo explica. |
| Fugas por RLS (ver datos de otros). | Alto | `shared_expenses` gobernada por `is_partner_member`; invites/partnerships solo para miembros; aceptación solo por RPC. `paid_by` validado contra los miembros del vínculo. |
| El nombre snapshot queda desactualizado si la persona cambia su nombre. | Bajo | Aceptable para MVP; se puede refrescar el snapshot en un spec futuro. |
| Desvincular deja gastos compartidos huérfanos. | Medio | `on delete cascade` en `shared_expenses.partnership_id` borra los gastos al desvincular; **confirmar con el usuario** si prefiere conservarlos (entonces no cascada + archivado). *(Pendiente de decisión antes de implementar.)* |
| Confusión sobre qué corre (migración vs schema). | Bajo | `14_gastos_compartidos.sql` es para DBs existentes; `schema.sql` para DB limpia, igual que en specs previos. |
| El usuario espera que el balance "sume" al total personal. | Bajo | Copy explícito de que compartidos son aparte e informativos; separación reforzada en UI. |

---

## Preguntas abiertas (a resolver antes de implementar)

1. **Al desvincular, ¿se borran los gastos compartidos o se conservan?** (Afecta si `shared_expenses.partnership_id` va con `on delete cascade` o con archivado.)
2. **¿El balance del mes o acumulado histórico?** El spec asume **por mes** (coherente con la app). Confirmar si además querés un acumulado total.
3. **¿Querés categorizar los gastos compartidos** (reusando tus categorías) en una segunda iteración, o quedan siempre sin categoría?

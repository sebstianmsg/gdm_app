# 01 — Migración a Flutter con acceso directo a Supabase

**Estado:** Implementado
**Fecha:** 2026-07-26
**Dependencias:** ninguna (primer spec del proyecto)

**Objetivo (una frase):** Migrar la capa de datos de `gdm_app` de un backend Node/Express (Dio + REST) a acceso directo a Supabase (`supabase_flutter`, Auth + Postgres + RLS con `ANON_KEY`), dejando la app funcional, testeada y documentada sobre una base de datos limpia.

---

## Alcance

**Dentro:**

1. **Base de datos (entregable `supabase/schema.sql`):** script SQL consolidado e idempotente para correr una vez sobre DB limpia. Incluye:
   - Tablas `categories` y `expenses` con `user_id NOT NULL` desde el arranque.
   - Función `delete_category(p_category_id, p_otros_id)` (reasigna gastos a "Otros" y borra la categoría).
   - Trigger `on_auth_user_created` sobre `auth.users` que siembra las 7 categorías default por usuario (paleta vibrante, "Otros" con `is_deletable=false`).
   - **RLS activado** en ambas tablas + policies `auth.uid() = user_id` (using + with check).
   - **Sin** inserts/backfills de datos viejos ni UUIDs hardcodeados.

2. **Dependencias:** agregar `supabase_flutter`; eliminar `dio` y `flutter_secure_storage` del `pubspec.yaml`.

3. **Config:** reescribir `lib/config/env.dart` como único lector de `--dart-define` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`); inicializar Supabase en el arranque.

4. **Capa de datos (reescritura):**
   - Auth vía SDK: `signInWithPassword`, sesión persistida por el SDK, logout.
   - Categorías/Gastos vía queries del SDK (`.from().select/insert/update`), filtro por mes en `expenses`, borrado de categoría vía **RPC** `delete_category`.
   - Adaptar mapeos de modelos (snake_case ↔ camelCase: `category_id`, `user_id`, `created_at`, etc.).
   - **Borrar** `api_client.dart`, `api_exception.dart`, `token_storage.dart`, `auth_api.dart`, `categories_api.dart`, `expenses_api.dart` y actualizar `core_providers.dart`.

5. **Tests (nivel medio):** tests de la capa de datos (mapeos y construcción de queries) y de providers, además de mantener verde el smoke test de login.

6. **Docs:** actualizar `README.md` con setup de Supabase, `--dart-define`, cómo correr desde Android Studio y cómo correr los tests.

**Fuera (explícito):**

- **Ejecución** del `schema.sql` sobre Supabase y creación del proyecto/usuarios: lo hace el usuario manualmente (la spec entrega el archivo, no lo corre).
- **Creación/push del repo GitHub** (`https://github.com/sebstianmsg/gdm_app.git`): se hace aparte, fuera de esta spec.
- **Migración de datos** de la DB vieja: se arranca con base limpia.
- **Registro de usuarios** en la app: es login-only; los usuarios se crean desde el dashboard de Supabase.
- **Cambios de UI/UX** de las features existentes (month, expenses, categories): solo cambia el origen de los datos, no el diseño.
- **Tests de integración** contra Supabase real/mock.

---

## Modelo de datos

La migración no introduce estructuras nuevas respecto al esquema destilado del `prespecinicial.md`; consolida el existente. Estas son las estructuras concretas que quedan definidas en `supabase/schema.sql` y sus modelos Dart correspondientes.

### Tabla `categories`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` |
| `name` | `text` | not null |
| `color` | `text` | hex, ej. `#FF6B6B` |
| `is_deletable` | `boolean` | not null, default `true`; `false` solo para "Otros" |
| `user_id` | `uuid` | not null, FK → `auth.users(id)` on delete cascade |
| `created_at` | `timestamptz` | default `now()` |

- Unicidad: `unique (user_id, name)`.
- RLS: `for all using (auth.uid() = user_id) with check (auth.uid() = user_id)`.

### Tabla `expenses`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` |
| `description` | `text` | not null |
| `amount` | `numeric(12,2)` | check `> 0` |
| `date` | `date` | not null |
| `category_id` | `uuid` | not null, FK → `categories(id)` on delete restrict |
| `user_id` | `uuid` | not null, FK → `auth.users(id)` on delete cascade |
| `created_at` | `timestamptz` | default `now()` |

- RLS: `for all using (auth.uid() = user_id) with check (auth.uid() = user_id)`.

### Categorías default (siembra por trigger)

| Nombre | Color | is_deletable |
|---|---|---|
| Almacén | `#FF6B6B` | true |
| Comida | `#FFD93D` | true |
| Transporte | `#4D96FF` | true |
| Servicios | `#C77DFF` | true |
| Salud | `#6BCB77` | true |
| Ocio | `#00C9A7` | true |
| Otros | `#FF9A3C` | **false** |

### Mapeo modelos Dart ↔ Postgres

- `Category`: `id`, `name`, `color`, `isDeletable ↔ is_deletable`, (`userId ↔ user_id`, `createdAt ↔ created_at` según se use).
- `Expense`: `id`, `description`, `amount`, `date`, `categoryId ↔ category_id`, (`userId ↔ user_id`, `createdAt ↔ created_at`).
- `Session`: se apoya en la sesión del SDK (`supabase.auth.currentSession/currentUser`); se revisa si el modelo actual sigue siendo necesario o se reduce.

**Nota:** `amount` viene como `num`/`String` desde Postgres `numeric` — el mapeo debe parsear a `double` de forma segura.

---

## Plan de implementación

Cada paso deja el sistema en un estado coherente (compila / testeable).

1. **Escribir `supabase/schema.sql`.** Script idempotente y consolidado: tablas `categories` y `expenses`, constraints, unicidad, función `delete_category`, trigger `on_auth_user_created` con siembra de las 7 categorías, RLS + policies en ambas tablas. Sin datos viejos. *(No se ejecuta aquí; el usuario lo corre en su Supabase nuevo.)*

2. **Dependencias.** En `pubspec.yaml`: agregar `supabase_flutter`; quitar `dio` y `flutter_secure_storage`. `flutter pub get`. La app aún no compila del todo (referencias rotas) — se arregla en los pasos siguientes.

3. **Config e inicialización.** Reescribir `lib/config/env.dart` para leer `SUPABASE_URL` y `SUPABASE_ANON_KEY` desde `--dart-define`. Inicializar `Supabase.initialize(...)` en `main()` antes de `runApp`.

4. **Auth.** Reescribir `auth_provider.dart` sobre el SDK: `signInWithPassword`, exponer sesión/usuario desde `supabase.auth`, logout. Eliminar `token_storage.dart` y `auth_api.dart`. La sesión la persiste el SDK.

5. **Capa de datos categorías.** Reescribir el acceso a categorías con `.from('categories').select()/insert()/update()` y el borrado vía RPC `delete_category`. Adaptar mapeo del modelo `Category`. Eliminar `categories_api.dart`.

6. **Capa de datos gastos.** Reescribir el acceso a gastos con el SDK, filtro por mes (`date` en rango `YYYY-MM`), insert/update/delete. Adaptar mapeo del modelo `Expense`. Eliminar `expenses_api.dart`.

7. **Limpieza de la capa Dio.** Eliminar `api_client.dart` y `api_exception.dart`; actualizar `core_providers.dart` para exponer el cliente Supabase y los nuevos providers de datos. Confirmar que ya no queda ninguna referencia a Dio/REST. La app compila (`flutter analyze` sin errores).

8. **Wiring UI.** Conectar las features existentes (`month`, `expenses`, `categories`) a los nuevos providers sin cambiar su diseño. Verificar flujo manual: login → ver mes → alta/edición/borrado de gasto → alta/borrado de categoría (RPC).

9. **Tests (nivel medio).** Actualizar el smoke test de login; agregar tests de mapeos de modelos (snake_case↔camelCase, parseo de `amount`) y de providers/capa de datos. `flutter test` verde.

10. **Docs.** Actualizar `README.md`: setup de Supabase, comando `flutter run --dart-define=...`, cómo correr desde Android Studio y cómo correr los tests.

---

## Criterios de aceptación

- [ ] Existe `supabase/schema.sql` que corre de una sola vez sobre una DB limpia sin errores y sin datos hardcodeados de usuarios viejos.
- [ ] El schema crea `categories` y `expenses` con `user_id NOT NULL`, constraints (`amount > 0`, unicidad `(user_id, name)`, FKs con `on delete` correctos).
- [ ] El schema define la función `delete_category` y el trigger `on_auth_user_created` que siembra exactamente las 7 categorías default con sus colores; "Otros" queda con `is_deletable = false`.
- [ ] RLS está habilitado en `categories` y `expenses`, cada una con policy `auth.uid() = user_id` (using + with check).
- [ ] `pubspec.yaml` incluye `supabase_flutter` y **no** incluye `dio` ni `flutter_secure_storage`.
- [ ] `lib/config/env.dart` lee `SUPABASE_URL` y `SUPABASE_ANON_KEY` desde `--dart-define`; `Supabase.initialize` corre antes de `runApp`.
- [ ] Ya no existen los archivos `api_client.dart`, `api_exception.dart`, `token_storage.dart`, `auth_api.dart`, `categories_api.dart`, `expenses_api.dart`.
- [ ] No queda ninguna referencia a Dio ni a endpoints REST (`/api/...`) en el código.
- [ ] Login funciona con `signInWithPassword`; la sesión persiste entre reinicios de la app; logout cierra sesión.
- [ ] Categorías y gastos se leen/crean/editan/borran vía SDK; el borrado de categoría usa la RPC `delete_category`; el filtro por mes en gastos funciona.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde, incluyendo el smoke test de login y los nuevos tests de mapeos de modelos y providers/capa de datos.
- [ ] `README.md` documenta setup de Supabase, el comando `flutter run --dart-define=...`, cómo correr desde Android Studio y cómo correr los tests.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Arquitectura de acceso a datos | Acceso directo Flutter → Supabase (Opción B) | Mantener backend Node/Express intermedio | Elimina una capa a mantener; RLS de Postgres cubre el aislamiento por usuario. |
| Aislamiento por usuario | RLS + policies `auth.uid() = user_id` | Filtrado manual en backend | Con `ANON_KEY` pública, RLS es la única capa válida; es feature nativa y gratis. |
| Base de datos | Base limpia desde cero | Migrar datos de la DB vieja | No hay datos productivos que preservar; el schema viejo es un log de migraciones sucio. |
| Ubicación del schema | `supabase/schema.sql` | `sql/` (estilo Node) / raíz | Convención del ecosistema Supabase. |
| Manejo de secretos | `--dart-define` + documentar en README | Archivo de config versionado/ignorado | Mantiene secretos fuera del repo sin infra extra. |
| Config en código | Reescribir `env.dart` como lector único | Eliminar `env.dart` / leer `--dart-define` disperso | Un solo punto de lectura de configuración. |
| Persistencia de sesión | Delegar en `supabase_flutter` | Conservar `flutter_secure_storage` + `token_storage` | El SDK ya persiste la sesión; el storage manual pierde sentido. |
| Capa Dio/REST | Borrado total | Conservar parcialmente | Toda la comunicación pasa al SDK; el código Dio queda muerto. |
| Registro de usuarios | Login-only, alta desde dashboard Supabase | Pantalla de registro en la app | Alcance acotado; usuarios administrados manualmente. |
| Cobertura de tests | Nivel medio (mapeos + providers/datos + smoke) | Solo smoke / integración con Supabase real | Balance costo/valor para cerrar la migración. |
| Ejecución del schema y repo GitHub | Fuera del alcance (los hace el usuario) | Incluirlos como pasos del spec | Requieren credenciales/entorno del usuario; la spec entrega artefactos. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| **RLS mal configurado** (policy ausente, o `using` sin `with check`) | Fuga de datos entre usuarios o inserts rechazados; con `ANON_KEY` no hay otra capa que proteja | Policies `for all` con `using` **y** `with check`; verificar manualmente con dos usuarios que cada uno solo ve lo suyo. |
| **Trigger `on_auth_user_created` con permisos/`search_path` incorrectos** | Usuarios nuevos sin sus 7 categorías; app arranca sin "Otros" y rompe el borrado por RPC | Trigger `security definer` con `search_path = public`; verificar la siembra al crear un usuario de prueba. |
| **Parseo de `amount` (`numeric` → Dart)** | Postgres devuelve `numeric` como `num`/`String`; un cast directo a `double` puede fallar o perder precisión | Parseo defensivo a `double` y test unitario del mapeo. |
| **RPC `delete_category` mal invocada** (nombres de parámetros/`p_otros_id`) | Falla el borrado de categorías; gastos quedan huérfanos | Test/manual del flujo de borrado; confirmar nombres de parámetros de la RPC contra el schema. |
| **Config faltante en `--dart-define`** | La app compila pero falla en runtime al inicializar Supabase con URL/key vacías | `env.dart` valida presencia de las variables y falla temprano con mensaje claro; documentado en README. |
| **Referencias residuales a Dio/REST** tras el borrado | Errores de compilación o código muerto | `flutter analyze` limpio como criterio de aceptación; buscar referencias a `/api/` y `dio`. |

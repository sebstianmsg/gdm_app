# Pre-spec inicial — gdm_app (migración a Flutter + acceso directo a Supabase)

Documento de contexto para la skill de **spec**. Resume el estado actual del proyecto
y las nuevas implementaciones acordadas, para arrancar la spec con contexto amplio.

---

## 1. Contexto y objetivo

- `gdm_app/` es la **migración a Flutter/Dart** de una app que antes era Node.js/Express
  (`../gdm/`, "Gastos del mes"). El proyecto Node se conserva **solo como referencia**.
- Objetivo de esta etapa: dejar la app Flutter **funcional, testeable y conectada a una
  base de datos Supabase nueva** (distinta de la del proyecto Node, pero con la misma
  estructura de tablas).
- Repo destino: `https://github.com/sebstianmsg/gdm_app.git`
  (⚠️ verificar el usuario correcto: `sebstianmsg` vs `sebastianmsg`).

## 2. Decisión de arquitectura: **Opción B — acceso directo a Supabase**

Se **elimina el backend Node.js/Express**. La app pasa a hablar directo con Supabase
(Auth + Postgres) usando el SDK `supabase_flutter`, con **RLS** como única capa de
aislamiento por usuario.

```
ANTES (estado actual del código):
  Flutter (Dio + Bearer) ──► Node/Express :3000 ──► Supabase (SERVICE_KEY, filtra por req.user.id)

DESPUÉS (objetivo de la spec):
  Flutter (supabase_flutter, ANON_KEY) ──► Supabase (Auth + Postgres + RLS)
```

- RLS está disponible en el **tier gratis** de Supabase (es feature nativa de Postgres).
- Con acceso directo la app usa la `ANON_KEY` (pública): **toda** la protección por
  usuario depende de las policies RLS. Hoy el esquema **no tiene RLS** (el aislamiento lo
  hacía el backend a mano) → escribir las policies es requisito ineludible.

## 3. Estado actual del proyecto Flutter (verificado)

- Flutter 3.44.8 / Dart 3.12.2 (SDK `^3.12.2`). `flutter pub get` ✅.
- `flutter test` ✅ 1/1 (solo un smoke test de login en `test/widget_test.dart`).
- `flutter analyze` ⚠️ 6 lints informativos (estilo, no bloqueantes).
- Dependencias actuales: `flutter_riverpod`, `dio`, `flutter_secure_storage`, `intl`,
  `google_fonts`. **No** está `supabase_flutter` todavía.

### Capa de datos actual (a reescribir)
- `lib/config/env.dart` — `API_BASE_URL` (default `http://10.0.2.2:3000`).
- `lib/data/api_client.dart` — cliente Dio, inyecta `Bearer`, maneja 401/timeouts.
- `lib/data/api_exception.dart`, `token_storage.dart` (flutter_secure_storage).
- `lib/data/auth_api.dart` — `POST /api/auth/login`.
- `lib/data/categories_api.dart` — CRUD `/api/categories`.
- `lib/data/expenses_api.dart` — CRUD `/api/expenses?month=YYYY-MM`.
- `lib/features/auth/auth_provider.dart` — sesión/gate de login.
- `lib/providers/core_providers.dart` — providers Riverpod (tokenStorage, apiClient, etc.).

### UI/features (se conservan; solo cambia de dónde vienen los datos)
- `lib/features/month/` — home, donut (painter), leyenda, movimientos, resumen por categoría.
- `lib/features/expenses/` — form, fila, diálogo de borrado.
- `lib/features/categories/` — modal y provider.
- `lib/models/` — `category.dart`, `expense.dart`, `session.dart`.
- `lib/theme/`, `lib/utils/`, `lib/widgets/`.

## 4. Esquema de datos (referencia: `../gdm/sql/schema.sql`)

`../gdm/sql/schema.sql` es un **log histórico de migraciones**, NO un instalador limpio:
tiene `ALTER TABLE`, `drop constraint` y backfills con UUIDs hardcodeados de usuarios
viejos (`2126b308-…`, `ecf6048c-…`). **No** reutilizarlo tal cual.

Estructura destilada:

- **categories**: `id uuid pk`, `name text`, `color text` (hex), `is_deletable bool`
  (false solo para "Otros"), `user_id uuid → auth.users`, `created_at`.
  Unicidad: `(user_id, name)`.
- **expenses**: `id uuid pk`, `description text`, `amount numeric(12,2) > 0`, `date date`,
  `category_id uuid → categories (on delete restrict)`, `user_id uuid → auth.users`,
  `created_at`.
- **función `delete_category(p_category_id, p_otros_id)`**: reasigna gastos a "Otros" y
  borra la categoría (server-side; se llamará por **RPC** desde el SDK).
- **trigger `on_auth_user_created`** sobre `auth.users`: siembra las **7 categorías
  default** por usuario nuevo (Almacén, Comida, Transporte, Servicios, Salud, Ocio, Otros)
  con la paleta vibrante. `security definer`, `search_path = public`.

Colores default: Almacén `#FF6B6B`, Comida `#FFD93D`, Transporte `#4D96FF`,
Servicios `#C77DFF`, Salud `#6BCB77`, Ocio `#00C9A7`, Otros `#FF9A3C`.

## 5. Alcance propuesto para la spec

### 5.1 Base de datos (Supabase nueva)
- Escribir un **`schema.sql` consolidado e idempotente** (una sola corrida sobre DB
  limpia), SIN los inserts/backfills de datos viejos. Debe incluir:
  - tablas `categories` y `expenses` con `user_id NOT NULL` de arranque.
  - función `delete_category` y trigger `on_auth_user_created` de siembra.
  - **RLS activado** en ambas tablas + policies por usuario, p.ej.:
    ```sql
    alter table expenses enable row level security;
    create policy "own expenses" on expenses
      for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
    ```
    (equivalente para `categories`).
- La app es **login-only** (no hay registro): los usuarios se crean desde el dashboard
  de Supabase (Authentication → Add user); el trigger les siembra las categorías.

### 5.2 App Flutter
- Agregar `supabase_flutter`; inicializar con `SUPABASE_URL` + `ANON_KEY` vía
  `--dart-define` (reemplaza `env.dart`/`API_BASE_URL`).
- Reescribir la capa de datos para usar el SDK en lugar de Dio/REST:
  - Auth: `signInWithPassword`, manejo de sesión y logout; reemplazar
    `token_storage`/`auth_api` (el SDK persiste sesión).
  - Categorías/Gastos: queries del SDK (`.from('...').select()/insert()/update()`),
    filtro por mes en `expenses`, borrado de categoría vía **RPC** `delete_category`.
  - Adaptar mapeos de modelos (snake_case ↔ camelCase: `category_id`, etc.).
- Actualizar/expandir **tests** (hoy solo hay 1 smoke test): providers y capa de datos.

### 5.3 Cierre
- Preparar el repo nuevo de GitHub (verificar nombre de usuario del remoto).
- Documentar en README: setup de Supabase, `--dart-define`, cómo correr desde Android
  Studio y cómo correr los tests.

## 6. Cómo correr (referencia)

- Android Studio: abrir `gdm_app/`, correr en emulador.
- CLI (tras migración):
  `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
- Tests: `flutter test`.

## 7. Decisiones pendientes / a confirmar en la spec

1. Nombre exacto del usuario/remoto de GitHub (`sebstianmsg` vs `sebastianmsg`).
2. ¿Se migran datos existentes de la DB vieja, o se arranca con base limpia?
   (asumido: **base limpia**, usuarios y categorías se generan de cero).
3. Estrategia de manejo de secretos (`--dart-define` vs archivo de config).
4. Nivel de cobertura de tests deseado para dar por cerrada la migración.

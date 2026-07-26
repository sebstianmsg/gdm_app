# gdm_app — Gastos del mes

App Flutter para registrar gastos mensuales, con acceso directo a **Supabase**
(Auth + Postgres + RLS). No hay backend intermedio: la app habla directo con
Supabase usando el SDK `supabase_flutter` y la `ANON_KEY` pública; el
aislamiento por usuario lo garantiza **Row Level Security**.

## Requisitos

- Flutter SDK (Dart `^3.12.2`).
- Un proyecto en [Supabase](https://supabase.com).
- Android Studio (o VS Code) para correr en emulador/dispositivo.

## Setup de Supabase

1. **Creá un proyecto** en el dashboard de Supabase.

2. **Corré el schema.** En el dashboard, abrí **SQL Editor** y pegá/ejecutá el
   contenido de [`supabase/schema.sql`](supabase/schema.sql). Es idempotente y
   se corre una sola vez sobre una base limpia. Crea:
   - Tablas `categories` y `expenses` (con `user_id NOT NULL`, constraints y FKs).
   - Función `delete_category` (reasigna gastos a "Otros" y borra la categoría).
   - Trigger `on_auth_user_created` que siembra 7 categorías default por usuario.
   - RLS + policies `auth.uid() = user_id` en ambas tablas.

3. **Creá los usuarios.** La app es *login-only* (no hay registro). Creá cada
   usuario desde **Authentication → Users** en el dashboard. Al crearse, el
   trigger le siembra automáticamente sus 7 categorías.

4. **Anotá las credenciales.** En **Project Settings → API**:
   - `Project URL` → `SUPABASE_URL`
   - `anon public` key → `SUPABASE_ANON_KEY`

## Configuración de la app (`--dart-define`)

Las credenciales **no se versionan**: se pasan en run/build time con
`--dart-define`. `lib/config/env.dart` es el único lector y falla temprano con
un mensaje claro si falta alguna.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu_anon_key
```

## Correr desde Android Studio

Como las variables van por `--dart-define`, hay que configurarlas en la
Run/Debug Configuration:

1. **Run → Edit Configurations…**
2. Seleccioná (o creá) la configuración de la app.
3. En **Additional run args** (o *Additional arguments*), agregá:

   ```
   --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co --dart-define=SUPABASE_ANON_KEY=tu_anon_key
   ```

4. Elegí el emulador/dispositivo y presioná **Run** (▶).

## Correr los tests

```bash
flutter test
```

Incluye:
- Smoke test de login (arranca mostrando la pantalla de login sin sesión).
- Tests de mapeo de modelos (`snake_case` ↔ `camelCase`, parseo de `amount`).
- Tests de los providers / capa de datos con dobles inyectados.

Los tests **no** requieren credenciales de Supabase ni conexión real.

## Estructura

- `lib/config/env.dart` — lectura de `--dart-define` (único punto de config).
- `lib/data/` — capa de datos sobre el SDK (`categories_data.dart`, `expenses_data.dart`).
- `lib/features/` — features de UI (`auth`, `month`, `expenses`, `categories`).
- `lib/providers/core_providers.dart` — cliente Supabase y providers de datos.
- `supabase/schema.sql` — schema consolidado de la base.

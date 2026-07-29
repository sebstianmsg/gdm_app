# gdm_app — Gastos del mes

App Flutter para registrar gastos mensuales, con acceso directo a **Supabase**
(Auth + Postgres + RLS). No hay backend intermedio: la app habla directo con
Supabase usando el SDK `supabase_flutter` y la `ANON_KEY` pública; el
aislamiento por usuario lo garantiza **Row Level Security**.

La autenticación soporta **registro y login por email/contraseña** (con
confirmación por email), **login nativo con Google** y **recuperación de
contraseña**, todo sobre Supabase Auth. Por ahora el foco es **Android**.

## Requisitos

- Flutter SDK (Dart `^3.12.2`).
- Un proyecto en [Supabase](https://supabase.com).
- Un proyecto en [Google Cloud](https://console.cloud.google.com) (para el login
  con Google).
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

3. **Usuarios.** Ya no hace falta crearlos a mano: la app tiene registro por
   email y login con Google. Al crearse el usuario (por cualquier vía), el
   trigger `on_auth_user_created` le siembra automáticamente sus 7 categorías.
   Si querés, todavía podés crear usuarios desde **Authentication → Users**.

4. **Anotá las credenciales.** En **Project Settings → API**:
   - `Project URL` → `SUPABASE_URL`
   - `anon public` key → `SUPABASE_ANON_KEY`

5. **Configurá Auth** (**Authentication → …**):
   - **URL Configuration → Redirect URLs:** agregá ambos deep links de la app:
     - `com.gdmapp://login-callback` (confirmación de email + callback de Google)
     - `com.gdmapp://reset-password` (link de reset de contraseña)
   - **Providers → Email:** dejá **Confirm email** habilitado (el registro exige
     confirmar la cuenta antes de iniciar sesión).
   - **Providers → Google:** habilitalo y pegá el **Web client ID** y el
     **Web client secret** de Google Cloud (ver sección siguiente). Este Web
     client ID es el mismo valor que se pasa como `GOOGLE_SERVER_CLIENT_ID`.
   - **Email Templates → Confirm signup / Reset password:** verificá que el link
     use la variable `{{ .ConfirmationURL }}`, de modo que respete el
     `redirectTo` que envía la app (los deep links de arriba).

## Setup de Google Cloud (login con Google)

El login usa `google_sign_in` + `signInWithIdToken` (hoja nativa de cuenta). Eso
requiere **dos** OAuth clients en **APIs & Services → Credentials**:

1. **OAuth client ID · Android:** package name `com.example.gdm_app` (el
   `applicationId` del proyecto) + el **SHA-1** de la firma. Obtené el SHA-1 con:

   ```bash
   cd android && ./gradlew signingReport
   ```

   (usá el SHA-1 de la variante `debug` para desarrollo; agregá el de `release`
   para producción). Este client no expone secret; habilita la firma del device.

2. **OAuth client ID · Web:** su **Client ID** es el que va como
   `GOOGLE_SERVER_CLIENT_ID` (`serverClientId` de `google_sign_in`) **y** el que
   se carga en el provider Google de Supabase junto con su secret. Es el que
   valida el `idToken`.

> Si el botón de Google falla con `idToken` nulo/ inválido: casi siempre es el
> SHA-1 mal cargado, el package name distinto, o el Web client ID no coincidente
> entre `GOOGLE_SERVER_CLIENT_ID` y el provider de Supabase.

## Configuración de la app (`--dart-define`)

Las credenciales **no se versionan**: se pasan en run/build time con
`--dart-define`. `lib/config/env.dart` es el único lector y falla temprano con
un mensaje claro si falta alguna.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu_anon_key \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
```

| Variable | Valor |
|---|---|
| `SUPABASE_URL` | Project URL de Supabase. |
| `SUPABASE_ANON_KEY` | `anon public` key de Supabase. |
| `GOOGLE_SERVER_CLIENT_ID` | **Web** client ID de Google Cloud (el mismo del provider Google en Supabase). |

## Deep links (Android)

La app registra el scheme `com.gdmapp://` en `AndroidManifest.xml` con dos hosts:

| URI | Uso |
|---|---|
| `com.gdmapp://login-callback` | Confirmación de email y callback de Google → sesión iniciada → home. |
| `com.gdmapp://reset-password` | Link de reset → abre la pantalla de nueva contraseña. |

Ambos deben estar cargados como **Redirect URLs** en Supabase (ver arriba).
`supabase_flutter` intercepta el link entrante automáticamente y emite el evento
por `onAuthStateChange`. Para probar un deep link sin el mail:

```bash
adb shell am start -a android.intent.action.VIEW -d "com.gdmapp://login-callback"
```

## Correr desde Android Studio

Como las variables van por `--dart-define`, hay que configurarlas en la
Run/Debug Configuration:

1. **Run → Edit Configurations…**
2. Seleccioná (o creá) la configuración de la app.
3. En **Additional run args** (o *Additional arguments*), agregá:

   ```
   --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co --dart-define=SUPABASE_ANON_KEY=tu_anon_key --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
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
- Validaciones de los formularios de auth (nombre, email, contraseña, confirmación).
- Transiciones de estado del `AuthNotifier` (`isSubmitting` / `error` / éxito).

Los tests **no** requieren credenciales de Supabase ni conexión real.

## Estructura

- `lib/config/env.dart` — lectura de `--dart-define` (único punto de config).
- `lib/data/` — capa de datos sobre el SDK (`categories_data.dart`, `expenses_data.dart`).
- `lib/features/` — features de UI (`auth`, `month`, `expenses`, `categories`).
- `lib/providers/core_providers.dart` — cliente Supabase y providers de datos.
- `supabase/schema.sql` — schema consolidado de la base.

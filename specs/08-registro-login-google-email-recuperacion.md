# SPEC 08 — Registro, login con Google y email, confirmación y recuperación de contraseña

> **Estado:** Approved
> **Dependencias:** SPEC 01 (auth sobre supabase_flutter, env.dart, _AuthGate), SPEC 03 (paleta morada / theme), SPEC 06 (AnimatedLoginBackground del login)
> **Fecha:** 2026-07-28
> **Objetivo:** Extender la autenticación login-only a un flujo completo de cuentas independientes: alta por email (nombre + email + contraseña) con confirmación por deep link, login con email/contraseña, login nativo con Google, recuperación de contraseña por email, y un checkbox "Recordarme" que controla si la sesión persiste al reabrir la app.

---

## Alcance

**Dentro:**

1. **Login con email/contraseña** (ya existe): se mantiene, sumando el checkbox "Recordarme", el link a "¿Olvidaste tu contraseña?" y el link a "Crear cuenta".

2. **Registro independiente por email** (`signup_screen.dart`): formulario con **nombre**, **email**, **contraseña** y **confirmar contraseña**. Llama a `signUp` pasando `data: {'full_name': ...}` (el nombre queda en `user_metadata`) y un `emailRedirectTo` con el deep link de confirmación. Tras el alta, muestra una pantalla/estado de **"Revisá tu email para confirmar tu cuenta"**.

3. **Confirmación de email por deep link:** al tocar el link del mail, se abre la app vía deep link; el SDK procesa el token, deja la sesión iniciada y la app navega al home.

4. **Login nativo con Google** (`google_sign_in` + `signInWithIdToken`): botón "Continuar con Google" que abre la hoja nativa de cuenta de Google y crea/inicia sesión en Supabase.

5. **Recuperación de contraseña:**
   - `forgot_password_screen.dart`: pide el email y llama a `resetPasswordForEmail` con el deep link de reset.
   - `reset_password_screen.dart`: se abre vía deep link tras tocar el link del mail; pide **nueva contraseña** + confirmación y llama a `updateUser`.

6. **Checkbox "Recordarme":** flag guardado en `SharedPreferences`. Si está **desmarcado**, al **arrancar la app** se hace `signOut()` antes de mostrar la UI (efecto: sin "recordarme", al reabrir la app quedás deslogueado). Aplica **solo al login por email**; el login con Google siempre persiste.

7. **Deep links Android:** definir el scheme `com.gdmapp://` con dos hosts — `login-callback` (Google + confirmación de email) y `reset-password` — en `AndroidManifest.xml`, y registrarlos como Redirect URLs en Supabase.

8. **Config:** agregar `GOOGLE_SERVER_CLIENT_ID` como `--dart-define` en `env.dart`; agregar dependencias `google_sign_in` y `shared_preferences` al `pubspec.yaml`.

9. **Tests (nivel medio):** validaciones de formularios (email, largo de contraseña, coincidencia de confirmación, nombre no vacío) y transiciones de estado del `AuthNotifier` para los nuevos métodos.

10. **Docs:** actualizar `README.md` con el setup de Google Cloud (client IDs / SHA-1), la config de Supabase (providers, redirect URLs, plantillas de email), el nuevo `--dart-define` y los deep links.

**Fuera de alcance (para futuros specs):**

- iOS y web (solo Android por ahora).
- Otros proveedores OAuth (Apple, Facebook, etc.).
- Tabla `profiles` o edición de perfil/nombre desde la app (el nombre solo se guarda en `user_metadata` al registrarse).
- Cambio de email o cambio de contraseña desde dentro de la sesión (esto cubre solo el reset vía email).
- Reenvío del email de confirmación / rate-limiting custom (se usa el comportamiento default de Supabase).
- Configuración real del proyecto Supabase y de Google Cloud (la hace el usuario; el spec entrega código y documentación, no credenciales).
- i18n / textos internacionalizados.
- Tests de integración contra Supabase o Google reales.

---

## Modelo de datos

Esta feature **no introduce tablas ni columnas nuevas** en Postgres. El nombre del usuario se guarda en `auth.users.user_metadata` (campo `full_name`), que ya provee Supabase Auth sin cambios de schema ni de trigger.

Se agrega **estado persistente local** mínimo, en `SharedPreferences`:

| Clave | Tipo | Uso |
|---|---|---|
| `remember_me` | `bool` | Escrita en cada login por email según el checkbox. Si es `false`, al arrancar la app se ejecuta `signOut()` antes de mostrar la UI. Ausente ⇒ se trata como `false` (no recordar). |

**Deep links (contrato de navegación):**

| URI | Origen | Destino en la app |
|---|---|---|
| `com.gdmapp://login-callback` | Confirmación de email + callback de Google | Sesión iniciada → home |
| `com.gdmapp://reset-password` | Link de reset de contraseña | `reset_password_screen.dart` |

**Config nueva (`env.dart`):**

| Variable (`--dart-define`) | Uso |
|---|---|
| `GOOGLE_SERVER_CLIENT_ID` | Web client ID de Google Cloud, pasado como `serverClientId` a `google_sign_in` y usado por Supabase para validar el `idToken`. |

---

## Plan de implementación

Cada paso deja el sistema compilando y testeable.

1. **Dependencias y config.** Agregar `google_sign_in` y `shared_preferences` al `pubspec.yaml` (`flutter pub get`). Agregar `GOOGLE_SERVER_CLIENT_ID` a `env.dart` (lectura + inclusión en `assertValid`, con mensaje claro). *Verificación:* `flutter analyze` limpio; la app sigue compilando.

2. **Deep links en Android.** En `AndroidManifest.xml` agregar los `intent-filter` para el scheme `com.gdmapp://` con hosts `login-callback` y `reset-password` (`android:autoVerify` no requerido para custom scheme). *Verificación:* build de Android OK; un deep link de prueba abre la app.

3. **Extender `AuthNotifier`** (`auth_provider.dart`) con los nuevos métodos, cada uno manejando `isSubmitting`/`error` como el `login` actual:
   - `signUpWithEmail(name, email, password)` → `signUp(..., data: {'full_name': name}, emailRedirectTo: 'com.gdmapp://login-callback')`.
   - `signInWithGoogle()` → `google_sign_in` (con `serverClientId`) + `signInWithIdToken(provider: google, idToken, accessToken)`.
   - `sendPasswordReset(email)` → `resetPasswordForEmail(email, redirectTo: 'com.gdmapp://reset-password')`.
   - `updatePassword(newPassword)` → `updateUser(UserAttributes(password: ...))`.
   - Guardar/leer el flag `remember_me` en `SharedPreferences` dentro de `login`.
   *Verificación:* `flutter analyze` limpio; tests de estado del notifier en verde.

4. **"Recordarme" al arranque.** En `main()` (o en el `build` del `AuthNotifier`), tras `Supabase.initialize`: si hay sesión restaurada y `remember_me == false`, ejecutar `signOut()` antes de `runApp`. *Verificación manual:* login sin marcar "Recordarme" → cerrar y reabrir la app → aparece el login; con "Recordarme" marcado → reabrir → entra directo al home.

5. **Login screen (`login_screen.dart`).** Agregar: checkbox "Recordarme", link "¿Olvidaste tu contraseña?" (navega a `forgot_password_screen`), link "Crear cuenta" (navega a `signup_screen`) y botón "Continuar con Google". *Verificación manual:* todos los controles visibles y navegables; login por email sigue funcionando.

6. **Registro (`signup_screen.dart`).** Formulario nombre + email + contraseña + confirmar contraseña, con validaciones (email válido, contraseña mínima, confirmación coincide, nombre no vacío). Al enviar, llama `signUpWithEmail`; en éxito muestra el estado "Revisá tu email para confirmar tu cuenta". *Verificación manual:* alta crea el usuario en Supabase (sin confirmar) y llega el email.

7. **Confirmación por deep link.** Verificar que al tocar el link del email se abre la app, el SDK emite la sesión por `onAuthStateChange` y `_AuthGate` navega al home. *Verificación manual:* flujo completo alta → email → deep link → home.

8. **Recuperación de contraseña.**
   - `forgot_password_screen.dart`: campo email + botón; llama `sendPasswordReset`; muestra confirmación "Te enviamos un email".
   - `reset_password_screen.dart`: se abre por el deep link `reset-password`; campos nueva contraseña + confirmación; llama `updatePassword`; en éxito vuelve al home/login.
   - Enrutar el deep link de reset hacia esta pantalla (escuchar `onAuthStateChange`/`PasswordRecovery` o el URI entrante). *Verificación manual:* olvido → email → deep link → nueva contraseña → login con la nueva.

9. **Tests (nivel medio).** Widget/unit de validaciones de los formularios (login, signup, forgot, reset) y transiciones de estado del `AuthNotifier` para los nuevos métodos. *Verificación:* `flutter test` en verde.

10. **Docs (`README.md`).** Setup de Google Cloud (OAuth client Android con SHA-1 + Web client ID), config de Supabase (habilitar Google provider, Redirect URLs `com.gdmapp://login-callback` y `com.gdmapp://reset-password`, plantillas de email de confirmación y reset), el nuevo `--dart-define=GOOGLE_SERVER_CLIENT_ID`, y explicación de los deep links. *Verificación:* un tercero puede reproducir la config siguiendo el README.

---

## Criterios de aceptación

- [ ] `pubspec.yaml` incluye `google_sign_in` y `shared_preferences`; `flutter pub get` corre sin errores.
- [ ] `env.dart` lee `GOOGLE_SERVER_CLIENT_ID` y `assertValid` falla con mensaje claro si falta.
- [ ] `AndroidManifest.xml` define intent-filters para `com.gdmapp://login-callback` y `com.gdmapp://reset-password`; un deep link a cada uno abre la app.
- [ ] Desde el login se puede navegar a "Crear cuenta" y a "¿Olvidaste tu contraseña?".
- [ ] El registro pide nombre, email, contraseña y confirmar contraseña, valida (email válido, contraseña con mínimo, confirmación coincide, nombre no vacío) y bloquea el envío si algo es inválido.
- [ ] Un alta exitosa crea el usuario en Supabase con `full_name` en `user_metadata`, muestra el aviso "Revisá tu email para confirmar tu cuenta" y dispara el email de confirmación.
- [ ] Tocar el link de confirmación abre la app vía deep link, inicia sesión y navega al home.
- [ ] El botón "Continuar con Google" abre la hoja nativa de Google e inicia/crea sesión en Supabase, quedando en el home.
- [ ] "¿Olvidaste tu contraseña?" envía el email de reset; el link abre `reset_password_screen` vía deep link, permite fijar una nueva contraseña (con confirmación) y luego se puede iniciar sesión con ella.
- [ ] El login por email con "Recordarme" **marcado** persiste la sesión: cerrar y reabrir la app entra directo al home.
- [ ] El login por email con "Recordarme" **desmarcado** no persiste: al reabrir la app aparece el login. El login con Google siempre persiste.
- [ ] Cada acción muestra estado de carga y errores legibles (reutilizando `isSubmitting`/`error` del `AuthState`), sin cerrar la app ante fallos.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde, incluyendo los tests de validaciones de formularios y de transiciones del `AuthNotifier`.
- [ ] `README.md` documenta el setup de Google Cloud, la config de Supabase (provider, redirect URLs, plantillas de email), el `--dart-define` nuevo y los deep links.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Mecanismo de Google Sign-In | Nativo: `google_sign_in` + `signInWithIdToken` | `signInWithOAuth` (navegador externo) | UX nativa (hoja de cuenta de Google) pedida por el usuario; a cambio requiere client IDs de Google Cloud. |
| Almacenamiento del nombre | `user_metadata.full_name` en el `signUp` | Tabla `profiles` dedicada | No toca schema ni el trigger de siembra; alcance acotado. |
| Confirmación de email | Deep link que abre la app | Página web de Supabase + login manual posterior | Mejor UX (continuidad); a cambio exige configurar scheme + redirect URLs. |
| Scheme de deep link | `com.gdmapp://` con hosts `login-callback` y `reset-password` | App Links con dominio verificado (`https://`) | Custom scheme no requiere hosting ni verificación de dominio; suficiente para Android. |
| "Recordarme" (persistencia) | Flag en `SharedPreferences` + `signOut()` al arranque si es `false` | Cosmético / recordar solo el email / deshabilitar el auto-persist del SDK | El SDK siempre persiste; interceptar en el arranque es la vía limpia para el comportamiento pedido (Opción B). |
| Alcance de "Recordarme" | Solo login por email; Google siempre persiste | Aplicarlo también a Google | Decisión explícita del usuario; simplifica el flujo OAuth. |
| Plataformas | Solo Android | Incluir iOS/web ahora | Foco actual del proyecto; evita configurar OAuth y deep links multiplataforma. |
| Reset de contraseña | Email + deep link a `reset_password_screen` (`updateUser`) | Cambio de contraseña dentro de la sesión | Cubre el caso de "contraseña olvidada"; el cambio in-session se difiere. |
| Estado de auth | Extender `AuthNotifier`/`AuthState` existentes | Crear providers separados por flujo | Reutiliza `isSubmitting`/`error` y `onAuthStateChange`; menor superficie de cambio. |
| Navegación | Mismo patrón existente (`_AuthGate` por estado + `Navigator` para pantallas de auth) | Introducir `go_router` | Consistencia con specs previos; no se justifica un router nuevo para 4 pantallas. |
| Cobertura de tests | Nivel medio (validaciones + estado del notifier) | Solo smoke / integración real con Supabase y Google | Balance costo/valor; los flujos externos no son testeables sin credenciales. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| **Google Sign-In mal configurado** (SHA-1 incorrecto, falta el Web client ID como `serverClientId`, o mismatch con el provider de Supabase) | El botón de Google falla con `idToken` inválido o `null`; login imposible | Documentar en README el paso a paso (client Android con SHA-1 + Web client ID); `env.dart` valida presencia de `GOOGLE_SERVER_CLIENT_ID`; probar en device real. |
| **Deep link no registrado / redirect URL no whitelisteada** en Supabase | El link de confirmación o de reset no abre la app o el SDK rechaza el redirect | Registrar ambos URIs como Redirect URLs en Supabase; verificar los intent-filters con un deep link de prueba antes del flujo completo. |
| **`signOut()` de "Recordarme" corre antes de restaurar la sesión** | Race: se cierra una sesión aún no cargada, o se muestra el home un instante antes de desloguear (parpadeo) | Ejecutar el chequeo del flag después de `Supabase.initialize` y antes de `runApp`; usar el estado `bootstrapping` de `_AuthGate` mientras se resuelve. |
| **Colisión entre callback de Google y de confirmación de email** (mismo host `login-callback`) | Enrutamiento ambiguo del deep link entrante | Diferenciar por el evento de `onAuthStateChange` (signedIn) en vez de parsear el host; reservar `reset-password` como host separado. |
| **Usuario intenta loguearse sin confirmar el email** | Error poco claro al hacer `signInWithPassword` | Mapear el error de Supabase a un mensaje legible ("Confirmá tu email antes de iniciar sesión"). |
| **Deep link de reset sin sesión de recovery válida** (link expirado o reusado) | `updateUser` falla al fijar la nueva contraseña | Manejar el error en `reset_password_screen` con mensaje claro y opción de reenviar el email desde "¿Olvidaste tu contraseña?". |

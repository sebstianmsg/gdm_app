# SPEC 22 — Captcha (Cloudflare Turnstile) en el registro y flujos de auth por email

> **Estado:** Approved
> **Depende de:** SPEC 08 (registro/login/reset por email sobre Supabase Auth, `AuthNotifier`, deep links), SPEC 01 (`env.dart`, cliente Supabase)
> **Fecha:** 2026-08-11
> **Objetivo:** Exigir un token de Cloudflare Turnstile —renderizado con `flutter_turnstile` y validado por Supabase Auth— en las llamadas de `signUp`, `signInWithPassword` y `resetPasswordForEmail`, para frenar el alta y el abuso automatizado de cuentas por bots, sin afectar el login con Google.

---

## Alcance

**Dentro:**

1. **Activar el captcha en Supabase Auth (config del proyecto, la hace el usuario):** en **Authentication → Settings → Bot & Abuse Protection**, habilitar **Cloudflare Turnstile** y cargar el **Turnstile secret key**. El spec entrega el código y la documentación; **no** las credenciales.

2. **Widget de captcha con `flutter_turnstile`:** agregar la dependencia al `pubspec.yaml` y renderizar el widget en las pantallas de auth por email, obteniendo el **token** que devuelve Turnstile al resolverse.

3. **Pasar el `captchaToken` en las tres llamadas del SDK** que Supabase exige una vez activado el captcha, extendiendo los métodos de `AuthNotifier` (SPEC 08):
   - `signUpWithEmail` → `signUp(..., captchaToken: ...)`
   - `login` (email/contraseña) → `signInWithPassword(..., captchaToken: ...)`
   - `sendPasswordReset` → `resetPasswordForEmail(..., captchaToken: ...)`

4. **Gating del envío:** el botón de cada uno de esos tres formularios (registro, login, forgot-password) queda **deshabilitado hasta tener un token válido**. Si el captcha falla, expira o no carga, se muestra error legible reutilizando el patrón `isSubmitting`/`error` del `AuthState`, sin cerrar la app.

5. **Reset del token tras usarlo o ante error:** un token de Turnstile es de un solo uso; tras un envío (exitoso o fallido) se resetea el widget para obtener uno nuevo antes de reintentar.

6. **Config nueva (`env.dart`):** agregar `TURNSTILE_SITE_KEY` como `--dart-define` (la site key es pública; va en el cliente), con validación en `assertValid` y mensaje claro si falta.

7. **Tests (nivel medio):** que los formularios bloquean el envío sin token y lo habilitan con token; que `AuthNotifier` propaga el `captchaToken` a las llamadas del SDK (con dobles inyectados).

8. **Docs (`README.md`):** setup de Cloudflare Turnstile (crear el widget, obtener site key + secret key), dónde se carga el secret en Supabase, el nuevo `--dart-define=TURNSTILE_SITE_KEY`.

**Fuera de alcance (para futuros specs):**

- **Login con Google:** no pasa por los endpoints de email, no lleva captcha.
- **`updatePassword`** en `reset_password_screen` (cambio efectivo de contraseña): Supabase **no** exige captcha ahí; queda igual.
- **hCaptcha** como alternativa (se eligió Turnstile).
- **Rate-limiting propio / WAF / protección DDoS a nivel red:** eso lo cubre Supabase/Cloudflare por infra, no este spec.
- **Reenvío del email de confirmación** y su captcha (comportamiento default de Supabase).
- **iOS/web:** foco Android, igual que SPEC 08.
- **i18n de los textos del captcha.**

---

## Modelo de datos

Esta feature **no introduce ni modifica tablas, columnas ni persistencia** en Postgres, ni estado local en `SharedPreferences`. El captcha es un token efímero de un solo uso que vive **en memoria** durante el flujo del formulario y se pasa a Supabase Auth; no se guarda.

**Config nueva (`env.dart`):**

| Variable (`--dart-define`) | Tipo | Uso |
|---|---|---|
| `TURNSTILE_SITE_KEY` | `String` | Site key **pública** de Cloudflare Turnstile. La lee `flutter_turnstile` para renderizar el widget. Validada en `assertValid` (falla temprano con mensaje claro si falta). |

**Estado efímero en el formulario (en memoria, no persistido):**

| Dato | Tipo | Uso |
|---|---|---|
| `captchaToken` | `String?` | Token que emite Turnstile al resolverse. `null` mientras no hay token válido ⇒ botón de envío deshabilitado. Se resetea a `null` tras cada envío (éxito o error) porque el token es de un solo uso. |

**Secret key (no vive en la app):** el **Turnstile secret key** se carga **solo en el dashboard de Supabase** (Authentication → Bot & Abuse Protection). Nunca se versiona ni se pasa por `--dart-define`; Supabase lo usa server-side para validar el token contra Cloudflare.

---

## Plan de implementación

Cada paso deja el sistema compilando y testeable.

1. **Dependencia y config.** Agregar `flutter_turnstile` al `pubspec.yaml` (`flutter pub get`). Agregar `TURNSTILE_SITE_KEY` a `env.dart` (lectura + inclusión en `assertValid`, con mensaje claro). *Verificación:* `flutter analyze` limpio; la app sigue compilando.

2. **Widget de captcha reutilizable.** Crear un componente (ej. `lib/features/auth/captcha_field.dart`) que envuelva `flutter_turnstile` con la `TURNSTILE_SITE_KEY`, exponga callbacks `onToken(String)` / `onError` / `onExpired` y un método para **resetear** el widget. *Verificación:* `flutter analyze` limpio; el widget renderiza en una pantalla de auth.

3. **Extender `AuthNotifier`** (`auth_provider.dart`) para propagar el token, manteniendo el patrón `isSubmitting`/`error`:
   - `login(email, password, captchaToken)` → `signInWithPassword(..., captchaToken: ...)`.
   - `signUpWithEmail(name, email, password, captchaToken)` → `signUp(..., captchaToken: ...)`.
   - `sendPasswordReset(email, captchaToken)` → `resetPasswordForEmail(..., captchaToken: ...)`.
   *Verificación:* `flutter analyze` limpio; tests de estado del notifier en verde.

4. **Integrar en `login_screen.dart`.** Renderizar el `captcha_field`; guardar el `captchaToken` en el estado del form; **deshabilitar el botón de login** hasta tener token; en el submit pasar el token a `login`; resetear el widget tras el envío (éxito o error). *Verificación manual:* sin token el botón está deshabilitado; con token resuelto el login funciona; un login fallido permite reintentar con token nuevo.

5. **Integrar en `signup_screen.dart`.** Mismo patrón: captcha + gating del botón de registro + pasar token a `signUpWithEmail` + reset tras envío. *Verificación manual:* alta bloqueada sin captcha; con captcha resuelto el alta crea el usuario y dispara el email.

6. **Integrar en `forgot_password_screen.dart`.** Mismo patrón: captcha + gating + pasar token a `sendPasswordReset` + reset tras envío. *Verificación manual:* el reset no se envía sin captcha; con captcha llega el email. (`reset_password_screen`/`updatePassword` **no** se toca.)

7. **Manejo de errores de captcha.** Mapear el fallo/expiración del widget y el rechazo del token por Supabase a mensajes legibles ("Verificá que no sos un robot" / "El captcha expiró, reintentá"), reutilizando `error` del `AuthState`, sin cerrar la app. *Verificación manual:* forzar token expirado/sin red muestra mensaje claro y permite reintentar.

8. **Tests (nivel medio).** Widget: el botón está deshabilitado sin token y habilitado con token, en los tres formularios. Unit: `AuthNotifier` propaga el `captchaToken` a las llamadas del SDK (dobles inyectados). *Verificación:* `flutter test` en verde.

9. **Docs (`README.md`).** Setup de Cloudflare Turnstile (crear el widget → site key + secret key), carga del **secret** en Supabase (Authentication → Bot & Abuse Protection → Turnstile), el nuevo `--dart-define=TURNSTILE_SITE_KEY`, y nota de que el captcha aplica a los tres flujos por email pero no a Google. *Verificación:* un tercero reproduce la config siguiendo el README.

---

## Criterios de aceptación

- [ ] `pubspec.yaml` incluye `flutter_turnstile`; `flutter pub get` corre sin errores.
- [ ] `env.dart` lee `TURNSTILE_SITE_KEY` y `assertValid` falla con mensaje claro si falta.
- [ ] Existe un widget de captcha reutilizable que renderiza Turnstile con la site key y expone token / error / expiración / reset.
- [ ] En **registro**, **login** y **forgot-password**, el botón de envío está **deshabilitado** mientras no haya token válido y se **habilita** al resolver el captcha.
- [ ] `AuthNotifier.login` pasa el `captchaToken` a `signInWithPassword`.
- [ ] `AuthNotifier.signUpWithEmail` pasa el `captchaToken` a `signUp`.
- [ ] `AuthNotifier.sendPasswordReset` pasa el `captchaToken` a `resetPasswordForEmail`.
- [ ] Con el captcha activado en Supabase, un alta con token válido crea el usuario y dispara el email de confirmación; un login con token válido inicia sesión; un reset con token válido envía el email.
- [ ] Tras cada envío (éxito o error) el widget de captcha se resetea y permite reintentar con un token nuevo.
- [ ] Un captcha fallido, expirado o sin red muestra un mensaje legible (reutilizando `error` del `AuthState`) sin cerrar la app.
- [ ] El **login con Google** sigue funcionando **sin** captcha.
- [ ] `reset_password_screen` / `updatePassword` no requiere captcha y sigue igual.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde, incluyendo los tests de gating del botón (3 formularios) y de propagación del `captchaToken` en `AuthNotifier`.
- [ ] `README.md` documenta el setup de Turnstile, la carga del secret en Supabase y el `--dart-define=TURNSTILE_SITE_KEY`.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Proveedor de captcha | **Cloudflare Turnstile** | hCaptcha | Gratis, menos fricción (casi invisible), soportado nativamente por Supabase Auth; elección del usuario. |
| Dónde se valida el token | **Supabase Auth** (server-side, con el secret en el dashboard) | Validar contra Cloudflare desde la app | La app no tiene backend; Supabase ya valida el `captchaToken` de forma nativa al activar el captcha. |
| Alcance de flujos cubiertos | **Los tres endpoints por email** (signUp, signInWithPassword, resetPasswordForEmail) | Solo el registro | Activar el captcha en Supabase es global para email: cubre los tres sí o sí; se asume explícitamente. |
| Login con Google | **Sin captcha** | Sumarle captcha | No pasa por los endpoints de email; Turnstile no aplica. |
| `updatePassword` (reset efectivo) | **Sin captcha** | Sumarle captcha | Supabase no lo exige en ese endpoint; se evita fricción innecesaria. |
| Paquete Flutter | **`flutter_turnstile`** | WebView propia / SDK JS manual | Widget listo para Turnstile, entrega el token con callbacks; menor superficie de código. Elección del usuario. |
| Site key vs secret key | **Site key por `--dart-define`** (pública en el cliente); **secret solo en Supabase** | Meter el secret en la app | El secret nunca va al cliente; la site key es pública por diseño. |
| Manejo del token | **Efímero en memoria, un solo uso, reset tras cada envío** | Cachear/reusar el token | Los tokens de Turnstile son de un solo uso; reusarlos falla la validación. |
| Estado de auth | **Extender `AuthNotifier`/`AuthState` existentes** | Providers nuevos | Reutiliza `isSubmitting`/`error`; mínima superficie de cambio, consistente con SPEC 08. |
| Encuadre del objetivo | **Frenar registros/abuso automatizado por bots** | Presentarlo como protección anti-DDoS/anti-caída de la base | Un captcha frena bots en el flujo de auth; el DDoS de infra lo maneja Supabase/Cloudflare a nivel red, no un captcha. |
| Cobertura de tests | **Nivel medio** (gating del botón + propagación del token) | Integración real contra Turnstile/Supabase | El captcha real no es testeable sin credenciales ni interacción humana; balance costo/valor. |

---

## Guía de configuración paso a paso (setup de las llaves)

Para que el captcha quede funcionando hay que tocar tres lugares en este orden: **Cloudflare** (crear el widget y sacar dos llaves), **Supabase** (pegar el secret y activar el captcha) y **Android Studio** (pegar la site key).

**Concepto:** Turnstile da dos llaves. La **site key** (pública) va en la app (`--dart-define=TURNSTILE_SITE_KEY`). La **secret key** (privada) va solo en Supabase, nunca en la app. La app muestra el captcha con la site key y obtiene un token; Supabase valida ese token contra Cloudflare usando la secret key.

### Paso 1 — Cloudflare: crear el widget y sacar las llaves

1. Entrar a https://dash.cloudflare.com (crear cuenta gratis si no hay).
2. En el menú lateral, **Turnstile** (bajo la sección de seguridad; usar el buscador si no aparece).
3. **Add widget** / **Add site**.
4. Completar:
   - **Widget name:** una etiqueta, ej. `gdm-app`.
   - **Hostname:** agregar `localhost` (en apps móviles el hostname no es estricto).
   - **Widget Mode:** dejar **Managed** (recomendado, casi invisible).
5. **Create**.
6. Copiar las dos llaves que muestra:
   - **Site Key** (`0x4AAAAAAA...`) → se usa en el Paso 3.
   - **Secret Key** (`0x4AAAAAAA...`) → se usa en el Paso 2.

### Paso 2 — Supabase: pegar el secret y activar el captcha

1. Entrar a https://supabase.com/dashboard y abrir el proyecto.
2. **Authentication → Settings** (o **Configuration**).
3. Sección **Bot and Abuse Protection** (según versión: "Attack Protection" / "CAPTCHA protection").
4. Activar **Enable CAPTCHA protection**.
5. En **Choose CAPTCHA provider** elegir **Turnstile by Cloudflare**.
6. En **CAPTCHA secret** pegar la **Secret Key** del Paso 1.
7. **Save**.

> ⚠️ Apenas se guarda, Supabase exige token en todos los login/registro/reset por email. Activar el captcha en Supabase recién cuando la app con `captchaToken` (esta rama) esté corriendo; si no, la auth por email deja de funcionar (ver Riesgos).

### Paso 3 — Android Studio: pegar la site key

1. Junto al botón ▶ Run, abrir el desplegable → **Edit Configurations...**.
2. Seleccionar la configuración de Flutter (la de `main.dart`).
3. En **Additional run args** (o "Additional arguments"), agregar al final (con un espacio antes):
   ```
   --dart-define=TURNSTILE_SITE_KEY=0x4AAAAAAA_tu_site_key
   ```
4. **Apply → OK** y volver a correr con ▶.

### Verificación

- La app ya no crashea al arrancar (desaparece el `StateError` de `Env.assertValid`).
- En **registro**, **login** y **recuperar contraseña** aparece el widget de Turnstile; el botón queda deshabilitado hasta resolver el captcha.
- Un registro/login/reset con el captcha resuelto funciona y Supabase acepta el token.

### Probar sin cuenta de Cloudflare (llaves de test)

Para destrabar el arranque sin crear el widget real, Cloudflare provee llaves de test:

- **Site key** en el Paso 3: `1x00000000000000000000AA` (siempre pasa), `2x00000000000000000000AB` (siempre falla), `3x00000000000000000000FF` (fuerza challenge interactivo).
- **Secret key** de test en el Paso 2: `1x0000000000000000000000000000000AA`.

Sirven para ver que la app arranca y la UI del captcha funciona; para auth real contra Supabase se necesitan las llaves reales de los Pasos 1 y 2.

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| **Captcha activado en Supabase pero la app aún no envía `captchaToken`** (deploy parcial: se activa el captcha antes de mergear este spec) | Todos los logins/altas/resets por email fallan con "captcha protection required" | Activar el captcha en Supabase **recién** cuando la app con `captchaToken` esté desplegada; documentar el orden en el README. |
| **Site key / secret key mal cargados o cruzados** (site key equivocada en la app, secret ausente en Supabase) | El widget no renderiza o Supabase rechaza el token; auth por email imposible | `env.dart` valida presencia de `TURNSTILE_SITE_KEY`; README con el paso a paso (site key en la app, secret en Supabase); probar en device real. |
| **Token de un solo uso reusado tras un reintento** | El segundo envío falla con token inválido y confunde al usuario | Resetear el widget tras cada envío (éxito o error) para forzar un token nuevo antes de reintentar (paso 4–6 del plan). |
| **Turnstile no carga (sin red, WebView bloqueada, host de Cloudflare inaccesible)** | El botón queda deshabilitado para siempre; el usuario no puede autenticarse | Mostrar error legible del callback `onError`, ofrecer reintento (reset del widget); dejar visible el estado "captcha no disponible". |
| **Token expira antes del envío** (Turnstile expira a los ~5 min) | El envío falla aunque el usuario resolvió el captcha | Manejar `onExpired` reseteando el token a `null` (rehabilita el captcha) y mensaje claro; volver a validar antes de enviar. |
| **`flutter_turnstile` renderiza vía WebView en Android** (dependencia de `webview_flutter`/permisos) | El widget no aparece en algún device/versión de Android | Verificar en device real; documentar la versión soportada; el gating evita enviar sin token si el widget no cargó. |

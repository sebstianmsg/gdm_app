# SPEC 31 — Remitente propio (Resend) y plantillas de email con branding de la app

> **Estado:** Cancelada
> **Depende de:** SPEC 08 (registro/login/reset por email sobre Supabase Auth, mails de confirmación y recuperación), SPEC 23 (nombre de la app "Gastos del Mes")
> **Fecha:** 2026-08-16
> **Objetivo:** Reemplazar el remitente por defecto de Supabase ("Supabase Auth") por un SMTP propio vía Resend con el nombre "Gastos del Mes", y rediseñar las plantillas de confirmación de cuenta y recuperación de contraseña con branding propio.

---

## Alcance

**Dentro:**

1. **Cuenta y dominio de envío en Resend (config del usuario):** crear cuenta en Resend. Como no hay dominio propio (decisión), se usa el remitente de prueba **`onboarding@resend.dev`** con **display name "Gastos del Mes"**. El spec entrega la documentación; **no** las credenciales.

2. **API key de Resend + SMTP propio en Supabase (config del usuario):** en **Authentication → Settings → SMTP Settings**, activar **Custom SMTP** con los datos de Resend (`smtp.resend.com`, puerto `465`, usuario `resend`, password = API key), y setear **Sender name = "Gastos del Mes"** y **Sender email = `onboarding@resend.dev`**. Esto elimina el remitente "Supabase Auth".

3. **Rediseño de la plantilla de confirmación de cuenta:** HTML propio con branding de "Gastos del Mes" (colores de la paleta morada del proyecto, nombre de la app, texto claro), manteniendo la variable `{{ .ConfirmationURL }}` que Supabase inyecta para el deep link de confirmación (`com.gdmapp://login-callback`).

4. **Rediseño de la plantilla de recuperación de contraseña:** mismo tratamiento de branding, manteniendo la variable de reset que Supabase inyecta hacia el deep link `com.gdmapp://reset-password`.

5. **Versionado del HTML en el repo:** guardar las dos plantillas en `docs/email-templates/confirmation.html` y `docs/email-templates/reset-password.html`, para que el HTML no viva solo en el dashboard y se pueda editar/revisar por control de versiones.

6. **Docs (`README.md`):** setup de Resend (crear cuenta, API key, remitente de prueba), config de Custom SMTP en Supabase (host/puerto/usuario/pass, sender name/email), y dónde pegar el HTML de cada plantilla (Authentication → Email Templates).

**Fuera de alcance (para futuros specs):**

- **Dominio propio verificado** en Resend (SPF/DKIM) para un remitente tipo `noreply@gastosdelmes.com`: se difiere hasta tener dominio; queda documentado como paso futuro.
- **Otras plantillas de Supabase** (magic link, cambio de email, invitación): hoy la app no las usa (SPEC 08 solo dispara confirmación y reset).
- **Cambios en el código de la app** (`auth_provider.dart`, pantallas): el flujo de `signUp`/`resetPasswordForEmail` no cambia; solo cambia el remitente y el HTML del mail.
- **i18n de los textos de los mails** (se hacen en español, como el resto de la app).
- **Límites de envío / analítica de Resend / webhooks de bounce:** fuera de alcance.
- **iOS/web:** foco Android, igual que SPEC 08.

---

## Modelo de datos

Esta feature **no introduce ni modifica tablas, columnas ni persistencia** en Postgres, ni estado local en `SharedPreferences`, ni estado en la app. No toca `env.dart` ni agrega `--dart-define` (la API key de Resend vive **solo en el dashboard de Supabase**, nunca en el cliente).

Los únicos artefactos nuevos son **archivos de plantilla versionados en el repo** (contenido, no estructuras de datos):

| Archivo | Uso |
|---|---|
| `docs/email-templates/confirmation.html` | HTML de la plantilla de confirmación de cuenta. Copia versionada de lo que se pega en Supabase → Email Templates → Confirm signup. Usa `{{ .ConfirmationURL }}`. |
| `docs/email-templates/reset-password.html` | HTML de la plantilla de recuperación de contraseña. Copia versionada de lo que se pega en Supabase → Email Templates → Reset password. Usa `{{ .ConfirmationURL }}`. |

**Variables de plantilla de Supabase (contrato, no se inventan):** el HTML debe conservar los placeholders que Supabase reemplaza server-side al enviar el mail (`{{ .ConfirmationURL }}` para el link de acción). Cambiar el nombre de la variable rompe el link del deep link.

**Credencial (no vive en la app):** la **API key de Resend** se carga **solo** en Supabase (Authentication → SMTP Settings como password del SMTP). Nunca se versiona ni se pasa por `--dart-define`.

---

## Plan de implementación

Cada paso deja el sistema en un estado funcional. Los pasos 1, 2 y 5 son config en dashboards (los hace el usuario siguiendo el README); los pasos 3 y 4 son archivos versionados en el repo.

1. **Resend: cuenta y API key (dashboard, usuario).** Crear cuenta en Resend, verificar el email de acceso, y generar una **API key**. Anotar que el remitente disponible sin dominio es `onboarding@resend.dev`. *Verificación:* la API key aparece listada en el dashboard de Resend.

2. **Supabase: activar Custom SMTP con Resend (dashboard, usuario).** En Authentication → Settings → SMTP Settings, activar Custom SMTP con host `smtp.resend.com`, puerto `465`, usuario `resend`, password = API key; Sender name `Gastos del Mes`, Sender email `onboarding@resend.dev`. Guardar. *Verificación:* enviar un mail de prueba (registro real o "reset password") y confirmar que llega **desde "Gastos del Mes"** y ya no desde "Supabase Auth".

3. **Plantilla de confirmación en el repo.** Crear `docs/email-templates/confirmation.html` con branding de la app (paleta morada, nombre "Gastos del Mes", botón de acción sobre `{{ .ConfirmationURL }}`, texto en español). *Verificación:* el archivo abre en un navegador y se ve el diseño; contiene `{{ .ConfirmationURL }}`.

4. **Plantilla de recuperación en el repo.** Crear `docs/email-templates/reset-password.html` con el mismo tratamiento de branding y `{{ .ConfirmationURL }}` como link de reset. *Verificación:* el archivo abre en un navegador; contiene `{{ .ConfirmationURL }}`.

5. **Cargar las plantillas en Supabase (dashboard, usuario).** En Authentication → Email Templates, pegar el HTML de `confirmation.html` en **Confirm signup** y el de `reset-password.html` en **Reset password**; ajustar el **Subject** de cada uno con texto propio. *Verificación:* un alta real llega con el diseño nuevo y el link abre la app vía deep link; un reset real llega con el diseño nuevo y su link abre `reset_password_screen`.

6. **Docs (`README.md`).** Documentar: setup de Resend (cuenta → API key → remitente `onboarding@resend.dev`), config de Custom SMTP en Supabase (host/puerto/usuario/pass, sender name/email), carga de las dos plantillas (qué archivo va en qué template + subjects), y nota de que el dominio propio verificado queda para un spec futuro. *Verificación:* un tercero reproduce toda la config siguiendo solo el README.

---

## Criterios de aceptación

- [ ] Supabase tiene **Custom SMTP** activado apuntando a Resend (`smtp.resend.com:465`, usuario `resend`, password = API key).
- [ ] El **Sender name** en Supabase es `Gastos del Mes` y el **Sender email** es `onboarding@resend.dev`.
- [ ] Un alta real dispara el mail de confirmación y este llega **desde "Gastos del Mes"**, ya **no** desde "Supabase Auth".
- [ ] Un "olvidé mi contraseña" real dispara el mail de reset y este llega **desde "Gastos del Mes"**.
- [ ] Existe `docs/email-templates/confirmation.html` con branding de la app y contiene `{{ .ConfirmationURL }}`.
- [ ] Existe `docs/email-templates/reset-password.html` con branding de la app y contiene `{{ .ConfirmationURL }}`.
- [ ] El mail de confirmación recibido usa el diseño nuevo y su botón/link abre la app vía deep link (`com.gdmapp://login-callback`) e inicia sesión.
- [ ] El mail de reset recibido usa el diseño nuevo y su link abre `reset_password_screen` (`com.gdmapp://reset-password`).
- [ ] El **Subject** de ambos templates es texto propio en español (no el default de Supabase).
- [ ] No se agregó ningún `--dart-define` nuevo ni cambió `env.dart`; la API key de Resend vive solo en Supabase.
- [ ] No cambió el código de la app (`auth_provider.dart` ni las pantallas de auth); el flujo de `signUp`/`resetPasswordForEmail` sigue igual.
- [ ] `README.md` documenta el setup de Resend, la config de Custom SMTP en Supabase, la carga de las dos plantillas y la nota del dominio propio como paso futuro.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Cómo cambiar el remitente | **SMTP propio (Custom SMTP en Supabase)** | Cambiar solo las plantillas | El nombre/dirección del remitente ("Supabase Auth") **no** se puede cambiar sin SMTP propio; las plantillas solo tocan el cuerpo. |
| Proveedor de email | **Resend** | SendGrid, Brevo, Mailgun, SMTP propio del dominio | Setup simple, plan free suficiente, buena documentación; elección del usuario. |
| Remitente concreto | **`onboarding@resend.dev`** (remitente de prueba de Resend) | Remitente sobre dominio propio (`noreply@gastosdelmes.com`) | No hay dominio propio hoy; el remitente de prueba ya elimina "Supabase Auth". El dominio verificado queda para un spec futuro. |
| Nombre del remitente | **"Gastos del Mes"** | "GDM" / otro | Es el nombre de la app (SPEC 23); consistencia de marca en la bandeja. |
| Plantillas cubiertas | **Confirmación de cuenta + recuperación de contraseña** | Magic link / cambio de email / invitación | Son las dos únicas que la app dispara hoy (SPEC 08); el resto no se usa. |
| Dónde vive el HTML | **Versionado en `docs/email-templates/` + pegado en el dashboard** | Solo en el dashboard de Supabase | El HTML en el repo permite revisión y edición por control de versiones; el dashboard es la fuente que envía. |
| Dónde vive la API key | **Solo en Supabase (SMTP settings)** | `--dart-define` / en la app | La API key es un secreto server-side; nunca debe ir al cliente. |
| Impacto en el código | **Cero cambios en la app** | Tocar `auth_provider.dart` o pantallas | El cambio es de remitente y contenido del mail; el flujo de Supabase Auth no cambia. |
| Idioma de los mails | **Español** | i18n / inglés | Coherente con el resto de la app; i18n se difiere. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| **`onboarding@resend.dev` con entrega limitada** (Resend restringe el remitente de prueba; a veces solo entrega al email dueño de la cuenta) | Los mails de confirmación/reset no llegan a usuarios reales | Verificar la entrega a un email externo en el paso 2; si Resend lo limita, priorizar el spec futuro de dominio propio verificado. |
| **Custom SMTP mal configurado** (puerto/usuario/password cruzados, API key inválida) | Supabase no puede enviar; altas y resets fallan silenciosamente | Enviar mail de prueba tras guardar; documentar host/puerto/usuario exactos en el README; regenerar la API key si falla. |
| **Se rompe el placeholder del link** (se edita `{{ .ConfirmationURL }}` al rediseñar el HTML) | El botón del mail no lleva al deep link; confirmación/reset imposibles | Conservar el placeholder textual exacto; verificar en el paso 5 que el link real abre la app. |
| **HTML en el repo se desincroniza del dashboard** (se edita el archivo y no se re-pega, o al revés) | La copia versionada deja de reflejar lo que se envía | Tratar el dashboard como fuente de envío y el repo como copia de revisión; documentar en el README que todo cambio se pega en ambos. |
| **Mails caen en spam** (remitente de prueba sin SPF/DKIM del dominio propio) | El usuario no ve el mail de confirmación | Aceptado como limitación del remitente de prueba; el dominio verificado (spec futuro) mejora la reputación de entrega. |
| **Rate limit de Resend en plan free** (tope mensual de envíos) | Con volumen alto, algunos mails no salen | Monitorear uso en Resend; fuera de alcance la analítica/webhooks, pero documentado como límite conocido. |

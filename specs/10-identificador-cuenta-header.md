# 10 — Identificador de cuenta en el header

> **Estado:** Approved
> **Dependencias:** spec 03 (paleta morada / header `_Header` en `home_screen.dart`), spec 08 (auth: `user_metadata.full_name`, login con Google)
> **Fecha:** 2026-07-31
> **Objetivo (una frase):** Mostrar en el header de la pantalla principal, debajo del botón de cerrar sesión, un identificador de la cuenta con ícono de persona, que use el nombre de usuario registrado y, si no existe, la parte del email anterior al `@`.

---

## Alcance

**Incluye:**

1. **Nuevo widget de identificador** en el header de la pantalla principal (`_Header` en `lib/features/month/home_screen.dart`), ubicado **debajo del botón de cerrar sesión**, alineado a la derecha en la misma columna que el botón.

2. **Ícono de persona** (`Icons.person`, tamaño pequeño, color `AppColors.textMuted`) a la izquierda del texto, sin saludo ni prefijo.

3. **Resolución del identificador** con esta cascada:
   - `user_metadata['full_name']` si no está vacío;
   - si no, `user_metadata['name']` si no está vacío (caso típico de Google);
   - si no, la parte del `email` anterior al `@` (ej. `sebastianmsg@outlook.com` → `sebastianmsg`).

4. **Truncado con "…"** (ellipsis en una sola línea) cuando el texto no entra en el ancho disponible.

5. Lectura del usuario desde `Supabase.instance.client.auth.currentUser`.

**No incluye:**

- Editar el nombre / perfil desde la app (el nombre solo proviene de `user_metadata`, tal como lo dejó spec 08).
- Mostrar el email completo, avatar/foto de Google, o cualquier otro dato de la cuenta.
- Tocar el header de otras pantallas (login, signup, etc.).
- Reactividad a cambios de nombre en tiempo real dentro de la misma sesión (se resuelve una vez al construir el header con el usuario actual).
- i18n / textos internacionalizados.

---

## Modelo de datos

No aplica. Esta feature no introduce estructuras nuevas; solo lee `currentUser` (email y `user_metadata`) que ya provee Supabase Auth desde spec 08.

---

## Plan de implementación

1. **Función de resolución del identificador.** Agregar un helper (privado en `home_screen.dart`, ej. `String _accountLabel(User? user)`) que aplique la cascada: `full_name` → `name` → parte del email antes del `@`. Si no hay usuario o email, devolver cadena vacía (el widget no se muestra). *Test:* unit test del helper con los tres casos (nombre presente, solo Google `name`, solo email) + caso email sin `@`. *Verificación:* `flutter test` en verde.

2. **Renderizar el identificador en `_Header`.** Debajo del `IconButton` de logout, dentro de la misma `Column` de la derecha, agregar una fila con `Icon(Icons.person, size: 14, color: AppColors.textMuted)` + `Text` con `overflow: TextOverflow.ellipsis` y ancho acotado (dentro de un `ConstrainedBox`/`Flexible`) para que trunque en una línea. Leer el usuario con `Supabase.instance.client.auth.currentUser`. *Verificación manual:* con una cuenta con nombre se ve el nombre; con una cuenta sin nombre se ve la parte previa al `@`.

3. **Ajuste de layout del header.** Envolver el `IconButton` + el identificador en una `Column` alineada a la derecha (`crossAxisAlignment: CrossAxisAlignment.end`), reemplazando el `IconButton` suelto actual. Verificar que el eyebrow/título de la izquierda sigan alineados y que un nombre largo trunque sin romper el layout. *Verificación manual:* probar con un `full_name` largo ("Juan Carlos Rodríguez Pérez") y confirmar el ellipsis.

---

## Criterios de aceptación

- [ ] En el header de la pantalla principal, **debajo del botón de cerrar sesión**, aparece un identificador con un ícono de persona a la izquierda y el texto a la derecha, sin saludo ni prefijo.
- [ ] Con una cuenta que tiene `user_metadata.full_name` no vacío, el identificador muestra ese nombre.
- [ ] Con una cuenta sin `full_name` pero con `user_metadata.name` (típico de Google), muestra ese `name`.
- [ ] Con una cuenta sin `full_name` ni `name`, muestra la parte del email anterior al `@` (ej. `sebastianmsg@outlook.com` → `sebastianmsg`, sin el `@`).
- [ ] Un identificador más ancho que el espacio disponible se **trunca con "…"** en una sola línea, sin romper ni desbordar el layout.
- [ ] El eyebrow "LIBRO DE GASTOS" y el título "Mis gastos" de la izquierda siguen visibles y correctamente alineados.
- [ ] El botón de cerrar sesión sigue funcionando igual que antes.
- [ ] Existe un test unitario del helper de resolución que cubre: nombre presente, solo `name` de Google, y solo email.
- [ ] `flutter analyze` no reporta errores y `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Ubicación del identificador | Debajo del botón de cerrar sesión (misma columna derecha) | Junto al título, o reemplazando el título | Pedido explícito del usuario; mantiene el bloque de identidad de cuenta agrupado arriba a la derecha. |
| Fuente del nombre | Cascada `full_name` → `name` → parte del email antes del `@` | Solo `full_name`, o mostrar el email completo | Cubre alta por email (spec 08 guarda `full_name`) y Google (suele traer `full_name`/`name`), con fallback siempre disponible. |
| Nombre para cuentas de Google | Tomar `full_name`/`name` de `user_metadata` de Google | Pedir un alias aparte, o usar el email de Google | Google ya provee el nombre de la cuenta; evita fricción extra. |
| Texto largo | Truncar con "…" en una línea | Dejar el texto completo aunque empuje el layout | Header de ancho fijo; el ellipsis evita romper la alineación. |
| Formato | Solo el texto con ícono de persona, sin saludo | "Hola, …" u otro prefijo | Pedido del usuario: identificador limpio. |
| Origen del dato | Leer `currentUser` una vez al construir el header | Suscribirse a cambios de nombre en tiempo real | El nombre no cambia dentro de la sesión (no hay edición de perfil en esta spec). |

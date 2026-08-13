# 11 — Tema claro y menú de usuario con selector de tema

> **Estado:** Implementado
> **Dependencias:** spec 03 (paleta morada, `AppColors`, `AppTheme.dark`, header `_Header`), spec 06 (fondo animado del login), spec 07 (confirmación de cerrar sesión), spec 08 (`SharedPreferences`, `user_metadata`), spec 10 (identificador de cuenta en el header)
> **Fecha:** 2026-07-31
> **Objetivo (una frase):** Agregar un modo claro (fondos blancos, botones morados con texto blanco) que convive con el modo oscuro actual mediante `ThemeData` + `ThemeExtension` y un `themeProvider` Riverpod persistido, y reemplazar el logout/identificador del header por un ícono de usuario que despliega un menú anclado con el nombre de cuenta, un selector cápsula sol/luna y "Cerrar sesión".

---

## Alcance

**Incluye:**

1. **Infraestructura de theming dual.**
   - Definir la paleta clara y oscura como dos juegos de tokens.
   - Crear una `ThemeExtension` propia (ej. `AppPalette`) que exponga los tokens que hoy son `AppColors` (`bg`, `surface`, `card`, `btn`, `btnHover`, `surface2`, `line`, `ink`, `inkText`, `text`, `textMuted`, `paper`, `alert`, `success`, `danger`), con una instancia para claro y otra para oscuro.
   - Construir `AppTheme.light` además de `AppTheme.dark`, cada uno con su `ColorScheme`, estilos de Material (botones, inputs, dialogs, snackbar, cards) y la `ThemeExtension` correspondiente.

2. **Migración de referencias de color a lectura por contexto.** Reemplazar los usos directos de `AppColors.<x>` en los ~17 archivos de widgets por lecturas de `Theme.of(context).extension<AppPalette>()!` (o helper equivalente), para que respondan al tema activo.

3. **`themeProvider` (Riverpod).** Un provider que expone el `ThemeMode` actual (`light`/`dark`), con acción para alternarlo, que persiste la elección en `SharedPreferences` (clave `theme_mode`, valores `'light'`/`'dark'`).

4. **Arranque con el tema correcto.** Leer `theme_mode` en `main.dart` antes de `runApp` y alimentar `MaterialApp.theme` (claro), `darkTheme` (oscuro) y `themeMode`. Default **oscuro** si no hay preferencia.

5. **Paleta clara concreta** (tokens): `bg #FFFFFF`, `surface #F5F2F8`, `card #FFFFFF`, borde `line` oscuro sutil (`#00000012`), `text #1A1024`, `textMuted` negro ~55%, `ink #64009D` (idéntico al oscuro), `inkText #FFFFFF`. Eyebrow y labels en **texto oscuro** en claro. `alert`/`success`/`danger` y colores de categorías del donut **idénticos** en ambos temas.

6. **Rediseño del área de usuario en el header** (`_Header` en `home_screen.dart`): arriba a la derecha queda **solo un ícono de usuario** (`Icons.person`), sin nombre ni texto. Se **eliminan** el botón de logout suelto y el identificador debajo (spec 10) de su posición actual.

7. **Menú de usuario anclado** (`PopupMenuButton` o menú anclado nativo, se cierra al tocar afuera, posicionado bajo el ícono) con, en orden:
   - **(a)** Encabezado con el nombre de cuenta (misma cascada del spec 10: `full_name` → `name` → parte del email antes del `@`).
   - **(b)** **Selector cápsula sol/luna** (sol = claro, luna = oscuro), que cambia el tema al instante dejando el menú abierto.
   - **(c)** **"Cerrar sesión"**, que conserva la confirmación del spec 07.

**No incluye:**

- Opción de tema "sistema"/automático (solo claro y oscuro explícitos).
- Editar el nombre/perfil desde la app (el nombre sigue viniendo de `user_metadata`).
- Variante clara del fondo animado del login: se mantiene **idéntico** en ambos temas.
- Reactividad al cambio de nombre en tiempo real dentro de la sesión.
- i18n / textos internacionalizados.
- Rediseño de contenidos más allá del arrastre de la nueva paleta y del área de usuario.

---

## Modelo de datos

No se introducen estructuras de dominio nuevas. El único estado persistente que se agrega es una preferencia local:

| Clave (`SharedPreferences`) | Tipo | Valores | Default (ausente) | Significado |
|---|---|---|---|---|
| `theme_mode` | `String` | `'light'` / `'dark'` | `'dark'` | Tema elegido por el usuario. Se lee en el arranque y se escribe al alternar desde la cápsula. |

Los tokens de color no son "datos" persistidos: viven en código como dos instancias de la `ThemeExtension` `AppPalette` (una clara, una oscura).

---

## Plan de implementación

1. **Definir la `ThemeExtension` `AppPalette` con los tokens actuales.** Crear `AppPalette extends ThemeExtension<AppPalette>` (ej. en `lib/theme/app_palette.dart`) con los campos que hoy son `AppColors` (`bg`, `surface`, `card`, `btn`, `btnHover`, `surface2`, `line`, `ink`, `inkText`, `text`, `textMuted`, `paper`, `alert`, `success`, `danger`), implementando `copyWith` y `lerp`. Definir dos instancias `const`: `AppPalette.dark` (valores actuales de `AppColors`) y `AppPalette.light` (paleta clara del alcance). *Verificación:* `flutter analyze` limpio; las instancias compilan.

2. **Construir `AppTheme.light` y adaptar `AppTheme.dark`.** Refactorizar `app_theme.dart` para que cada tema arme su `ThemeData` a partir de su `AppPalette` (colorScheme, cards, inputs, dialogs, snackbar, botones) y registre la extensión en `extensions: [palette]`. `AppTheme.dark` debe verse **idéntico** al actual. `AppTheme.light` usa la paleta clara: fondo blanco, botones morados con texto blanco, eyebrow/labels en texto oscuro. *Verificación:* app arranca en oscuro sin cambios visuales respecto de hoy.

3. **Migrar las referencias `AppColors.<x>` a lectura por contexto.** En los ~17 archivos de widgets, reemplazar `AppColors.<x>` por `Theme.of(context).extension<AppPalette>()!.<x>` (o un helper `context.palette`). Para `AppTextStyles` (que hoy fija colores en `const`/estáticos), pasar los estilos a resolverse con el color del tema en el punto de uso (o parametrizar el color). *Verificación:* `flutter analyze` limpio; en oscuro todo se ve igual que hoy.

4. **Crear el `themeProvider` con persistencia.** Provider Riverpod (ej. `StateNotifier<ThemeMode>`) que inicializa desde `theme_mode` de `SharedPreferences`, expone `toggle()`/`setMode()` y escribe el valor al cambiar. *Verificación:* alternar el modo persiste tras cerrar y reabrir la app.

5. **Cablear el tema en `main.dart`.** Leer `theme_mode` antes de `runApp` para el primer frame, y en `MaterialApp` setear `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `themeMode:` desde el `themeProvider`. Default **oscuro**. *Verificación:* sin preferencia guardada arranca en oscuro; con `'light'` arranca en claro desde el primer frame (sin parpadeo).

6. **Rediseñar el área de usuario en `_Header` (`home_screen.dart`).** Quitar el `IconButton` de logout suelto y el identificador de cuenta debajo (spec 10) de su posición actual. Dejar arriba a la derecha **solo** un ícono de usuario (`Icons.person`) como disparador del menú. *Verificación manual:* el header muestra solo el ícono de usuario a la derecha; el eyebrow y "Mis gastos" siguen a la izquierda.

7. **Implementar el menú de usuario anclado.** `PopupMenuButton` (o menú anclado nativo) que se cierra al tocar afuera, posicionado bajo el ícono, con: (a) encabezado no seleccionable con el nombre de cuenta (cascada `full_name` → `name` → parte antes del `@`, reutilizando el helper del spec 10); (b) el selector cápsula sol/luna; (c) "Cerrar sesión". *Verificación manual:* al tocar el ícono aparece el menú con los tres elementos en orden.

8. **Selector cápsula sol/luna.** Widget cápsula de dos estados (sol = claro, luna = oscuro) que refleja el `themeMode` actual y al tocar llama al `themeProvider`; el cambio es **instantáneo** y el menú **permanece abierto** para ver el cambio. *Verificación manual:* tocar sol pasa a claro y luna a oscuro sin cerrar el menú; el estado seleccionado se resalta.

9. **"Cerrar sesión" dentro del menú con confirmación del spec 07.** El ítem dispara el mismo diálogo de confirmación existente antes de cerrar sesión. *Verificación manual:* tocar "Cerrar sesión" muestra el diálogo "¿Cerrar sesión?"; confirmar desloguea, cancelar vuelve.

10. **Repaso integral de contraste en claro.** Recorrer login (con fondo animado idéntico), home, modales (gasto, categorías), reset password en **modo claro**, verificando que no queden textos blancos sobre blanco ni acentos ilegibles. *Verificación manual + `flutter test` verde.*

---

## Criterios de aceptación

- [ ] Existe una `ThemeExtension` `AppPalette` con dos instancias (clara y oscura) que cubren todos los tokens que antes eran `AppColors`.
- [ ] `AppTheme.dark` se ve **idéntico** a la versión previa a esta spec (sin regresiones visuales en oscuro).
- [ ] Existe `AppTheme.light` con: fondo `#FFFFFF`, tarjetas/superficies según la paleta clara, botones morados (`#64009D`) con texto blanco, eyebrow y labels en texto oscuro.
- [ ] `ink` es `#64009D` en ambos temas; `alert`, `success`, `danger` y los colores de categorías del donut son idénticos en claro y oscuro.
- [ ] Ningún widget usa ya `AppColors.<x>` de forma que no reaccione al tema; los colores se resuelven desde el tema activo por contexto.
- [ ] En modo claro no hay textos blancos sobre fondo blanco ni acentos ilegibles en login, home, modales de gasto/categorías y reset password.
- [ ] El fondo animado del login es idéntico en ambos temas.
- [ ] Existe un `themeProvider` Riverpod que alimenta `MaterialApp.themeMode`.
- [ ] La elección de tema se persiste en `SharedPreferences` bajo `theme_mode` (`'light'`/`'dark'`) y sobrevive a cerrar y reabrir la app.
- [ ] Sin preferencia guardada, la app arranca en **oscuro**; con `'light'` guardado arranca en claro desde el primer frame, sin parpadeo de tema.
- [ ] En el header, arriba a la derecha, hay **solo** un ícono de usuario (`Icons.person`), sin nombre ni texto; ya no está el botón de logout suelto ni el identificador debajo.
- [ ] Al tocar el ícono se abre un menú anclado que se cierra al tocar afuera, con, en orden: (a) el nombre de cuenta como encabezado, (b) el selector cápsula sol/luna, (c) "Cerrar sesión".
- [ ] El nombre del encabezado usa la cascada `full_name` → `name` → parte del email antes del `@`.
- [ ] El selector cápsula muestra sol y luna, refleja el tema activo, y al tocar cambia el tema al instante dejando el menú abierto.
- [ ] "Cerrar sesión" dentro del menú mantiene la confirmación del spec 07 (diálogo "¿Cerrar sesión?").
- [ ] `flutter analyze` no reporta errores y `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Arquitectura del theming | `ThemeData` claro/oscuro + `ThemeExtension` (`AppPalette`) con tokens propios | (a) Migrar todo a `ColorScheme` puro; (b) provider de paleta; (c) mutar `AppColors` en runtime | La `ThemeExtension` centraliza los tokens no estándar y cambia con el tema de forma idiomática, sin hacks de mutación global. |
| Estado del tema | `themeProvider` Riverpod que alimenta `themeMode` | Estado local / `InheritedWidget` ad-hoc | Consistente con el uso de Riverpod para auth; reactivo en toda la app. |
| Persistencia | `SharedPreferences`, clave `theme_mode` (`'light'`/`'dark'`) | Guardar en Supabase / por cuenta | Preferencia local de dispositivo; consistente con `remember_me` (spec 08). |
| Tema por defecto | Oscuro | Claro / "sistema" | No altera la experiencia actual; el usuario opta por claro explícitamente. |
| Opción "sistema" | No incluida | Seguir el tema del SO | Pedido acotado a dos estados sol/luna; evita ambigüedad en la cápsula. |
| Acento morado en claro | `#64009D` idéntico al oscuro | `#4C0078` más oscuro | Mantiene identidad de marca y cumple contraste con texto blanco encima. |
| Superficies en claro | `bg #FFFFFF`, `surface #F5F2F8`, `card #FFFFFF`, texto `#1A1024` | Tarjetas 100% blancas sin gris-lila | El gris-lila muy sutil da separación de tarjetas sin perder el look claro. |
| Eyebrow/labels en claro | Texto oscuro | Morado / blanco | El blanco desaparece sobre fondo claro; el texto oscuro asegura legibilidad. |
| Fondo del login | Idéntico en ambos temas | Variante clara | Ya funciona como bloque de marca morado; evita rediseñar el spec 06. |
| Colores de estado y donut | Idénticos en ambos temas | Recolorearlos por tema | Mantienen su semántica (alerta/éxito/peligro) y la identidad de categorías. |
| Área de usuario | Ícono de usuario que abre un menú anclado con nombre + cápsula + logout | Mantener logout + identificador sueltos (spec 03/10) | Agrupa identidad y acciones de cuenta; libera el header. |
| Tipo de desplegable | Menú anclado nativo (`PopupMenuButton`) | Panel/overlay custom | Simplicidad, cierre al tocar afuera y posicionamiento resueltos por Material. |
| Cierre del menú al cambiar tema | El menú permanece abierto | Cerrarlo al togglear | Permite ver el cambio de tema aplicado en el acto. |
| Confirmación de logout | Se conserva la del spec 07 | Logout directo desde el menú | Mantiene la salvaguarda ya definida. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Migrar ~100 referencias `AppColors.<x>` en 17 archivos introduce regresiones visuales en oscuro | Alto | Verificar tras la migración que el modo oscuro se ve **idéntico** al actual antes de tocar la paleta clara; recorrido visual pantalla por pantalla. |
| `AppTextStyles` fija colores en estáticos/`const` y no reacciona al tema | Medio | Resolver el color de esos estilos en el punto de uso (o parametrizarlo) para que tome el token del tema activo. |
| Parpadeo de tema al arrancar si `theme_mode` se lee tarde | Medio | Leer `SharedPreferences` antes de `runApp` y pintar el `themeMode` correcto desde el primer frame. |
| Contraste insuficiente en claro en algún texto atenuado o superficie | Medio | Repaso de contraste dedicado (paso 10) en login, home, modales y reset password. |
| Referencias residuales a `AppColors` que queden hardcodeadas y no cambien de tema | Bajo | Búsqueda global de `AppColors.` al cierre; no debe quedar ninguna que no pase por el tema. |

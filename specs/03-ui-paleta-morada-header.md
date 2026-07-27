# 03 — Rediseño de UI: paleta morada, textos blancos y reordenamiento del header

**Estado:** Implementada
**Fecha:** 2026-07-27
**Dependencias:** SPEC 01, SPEC 02

**Objetivo (una frase):** Rediseñar la UI de la pantalla principal reemplazando el acento verde por una paleta morada (`#64009D` principal, `#4C0078` secundario) con textos en blanco, renombrando "Gastos del mes" a "Mis gastos", moviendo la gestión de categorías a un ícono de lápiz dentro del donut y reubicando el botón de salir a la esquina superior derecha.

---

## Alcance

**Dentro:**

1. **Renombrar título del header:** "Gastos del mes" → **"Mis gastos"** (`home_screen.dart:116`).

2. **Nueva paleta morada (mapeo Opción A) en `app_colors.dart`:**
   - `ink` (acento): verde `#4FAE84` → **`#64009D`** (morado principal). Afecta botón "+", foco de inputs, eyebrow, borde/texto de botones outlined.
   - Superficies de contraste (`surface`, `card`, `surface2`, `btn`, `btnHover`): pasan a tonos derivados de **`#4C0078`** (secundario) para dar contraste sobre el fondo.
   - `bg`: se mantiene oscuro (morado muy oscuro casi negro) para no perder legibilidad.
   - `inkText` (texto sobre botón primario): `#0D1512` → **blanco** (`#FFFFFF`). Esto arrastra a blanco el texto de los botones "Agregar" (categorías) e "Iniciar sesión".

3. **Textos en blanco:**
   - `eyebrow` ("LIBRO DE GASTOS") pasa de morado/acento a **blanco** (`AppTextStyles.eyebrow`, `app_theme.dart:104`).
   - Se mantienen los textos atenuados existentes (`textMuted`, labels "TOTAL DEL MES", "POR CATEGORÍA") con su opacidad actual, para conservar jerarquía.

4. **Botón "Categorías" dentro del donut:**
   - Se **elimina** el `OutlinedButton` "Agregar/Modificar categoría" del header (`home_screen.dart:123-126`).
   - Se agrega un `IconButton` con ícono de lápiz (`Icons.edit` de Flutter) dentro de `DonutCard`, en la parte superior derecha (fila opuesta a "POR CATEGORÍA"), que abre el modal de categorías (`showCategoriesModal`). Solo el ícono es clickeable.

5. **Reubicar botón de salir:**
   - El `IconButton` de logout (`home_screen.dart:128-132`) se mueve a la esquina superior derecha, flotando sobre todo, alineado verticalmente con el eyebrow "LIBRO DE GASTOS".

**Fuera de alcance (para futuros specs):**

- Splash screen e ícono de la app (explícitamente diferidos por el usuario).
- Importar el PNG de referencia (`Editar.png`) como asset — se usa un ícono nativo de Flutter.
- Rediseño de los modales internos (agregar gasto, categorías) más allá del arrastre automático de la paleta.
- Modo claro / theming dinámico.
- Cambios de tipografía o de layout de las tarjetas de mes y movimientos.

---

## Plan de implementación

1. **Redefinir la paleta en `lib/theme/app_colors.dart`.** Cambiar `ink` a `#64009D`, derivar `surface`/`card`/`surface2`/`btn`/`btnHover` de `#4C0078`, ajustar `bg` a un morado muy oscuro, y cambiar `inkText` a blanco (`#FFFFFF`). *Test manual:* la app arranca y todo el acento verde desapareció; los botones "+", "Agregar" e "Iniciar sesión" se ven morados con texto blanco.

2. **Poner el eyebrow en blanco en `lib/theme/app_theme.dart`.** Cambiar `AppTextStyles.eyebrow.color` de `AppColors.ink` a `AppColors.text` (blanco). *Test manual:* "LIBRO DE GASTOS" se ve blanco, no morado.

3. **Renombrar el título en `home_screen.dart`.** Reemplazar `Text('Gastos del mes', ...)` por `Text('Mis gastos', ...)` (línea 116). *Test manual:* el header muestra "Mis gastos".

4. **Reestructurar el header en `home_screen.dart`.** Quitar el `OutlinedButton` de categorías y dejar el `IconButton` de logout flotando en la esquina superior derecha, alineado con el eyebrow (fila superior: bloque "LIBRO DE GASTOS / Mis gastos" a la izquierda, botón salir arriba a la derecha). Ajustar la firma de `_Header` para que ya no reciba `onManageCategories`. *Test manual:* el botón de salir queda arriba a la derecha; ya no hay botón de categorías en el header.

5. **Agregar el ícono de categorías en `donut_card.dart`.** En la fila superior del `DonutCard`, poner "POR CATEGORÍA" a la izquierda y un `IconButton(Icons.edit)` a la derecha (usar un `Row` con `Spacer`/`spaceBetween`). Pasar el callback `onManageCategories` a `DonutCard` desde `home_screen.dart` (que llama a `showCategoriesModal`). *Test manual:* dentro de la tarjeta del donut, arriba a la derecha aparece el lápiz; al tocarlo abre el modal de categorías.

6. **Verificación integral.** `flutter analyze` limpio, `flutter test` verde, y revisión visual de que no quedó ningún acento verde ni texto perdido sobre el nuevo fondo. *Test manual:* recorrer login → home → modal categorías → agregar gasto.

---

## Criterios de aceptación

- [ ] El header muestra el título **"Mis gastos"** (ya no "Gastos del mes").
- [ ] `AppColors.ink` es `#64009D`; ya no existe el verde `#4FAE84` en `app_colors.dart`.
- [ ] Las superficies (`surface`, `card`, `surface2`, `btn`, `btnHover`) derivan de `#4C0078`; `bg` es un morado muy oscuro.
- [ ] `AppColors.inkText` es blanco; el texto de los botones "Agregar" (categorías) e "Iniciar sesión" se ve **blanco**.
- [ ] El eyebrow "LIBRO DE GASTOS" se ve **blanco** (no morado ni verde).
- [ ] El botón "Agregar/Modificar categoría" **ya no existe** en el header.
- [ ] Dentro de `DonutCard`, en la parte superior derecha (opuesta a "POR CATEGORÍA"), hay un ícono de lápiz (`Icons.edit`) que al tocarlo abre el modal de categorías; solo el ícono es clickeable.
- [ ] El botón de salir está en la esquina superior derecha, alineado verticalmente con el eyebrow "LIBRO DE GASTOS", y sigue cerrando sesión.
- [ ] No queda ningún acento verde visible en la pantalla principal ni en los modales.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Mapeo de la paleta morada | Opción A: `#64009D` reemplaza el acento `ink`, `#4C0078` deriva las superficies, `bg` sigue oscuro | Usar `#64009D` como fondo general | Mantener un fondo oscuro conserva legibilidad y contraste; el morado como acento respeta la estructura de tema existente. |
| Texto sobre botón primario | `inkText` → blanco (arrastra "Agregar" e "Iniciar sesión") | Cambiar el color en cada botón por separado | Un solo token (`inkText`) ya alimenta todos los botones primarios; centraliza el cambio. |
| Textos atenuados | Conservar `textMuted` y labels con su opacidad | Poner todo blanco puro 100% | Se mantiene jerarquía visual; solo el eyebrow pasa a blanco por pedido explícito. |
| Ícono de categorías | `Icons.edit` de la librería de Flutter | Importar `Editar.png` como asset | Evita gestionar un asset extra; el ícono nativo cumple la referencia. |
| Ubicación del ícono de categorías | Dentro de `DonutCard`, arriba a la derecha | Mantenerlo en el header | Pedido explícito del usuario; agrupa la acción con su contexto (el gráfico por categoría). |
| Botón de salir | Flotando arriba a la derecha, alineado con el eyebrow | Fila superior dedicada solo para salir | Pedido explícito del usuario; aprovecha el espacio del header sin agregar una fila. |
| Splash screen e ícono de app | Fuera de alcance | Incluirlos aquí | El usuario los difirió explícitamente a un spec siguiente. |

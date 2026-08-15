# SPEC 25 — Título del login adaptado al tema (textos "LIBRO DE GASTOS" y "Mis gastos")

> **Estado:** Implementado
> **Depende de:** SPEC 09 (título "Mis gastos" en el login), SPEC 11 (theming dual `AppTheme`/`AppPalette`/`context.palette`), SPEC 24 (fondo del login por tema)
> **Fecha:** 2026-08-15
> **Objetivo (una frase):** Que los dos textos del encabezado del login (`'LIBRO DE GASTOS'` y `'Mis gastos'`) usen el color de texto del tema activo (`context.palette.text`) en lugar del claro fijo `AppPalette.dark.text`, para que se lean bien en modo claro igual que el resto de los textos del login.

---

## Alcance

**Dentro:**

1. Cambiar el color de los dos `Text` del encabezado en `lib/features/auth/login_screen.dart` (líneas ~87 y ~93): de `AppPalette.dark.text` a `context.palette.text`, quedando adaptativos (oscuro en modo claro, claro en modo oscuro).
2. Actualizar el comentario de las líneas 84-85 que justifica el color claro fijo, ya que deja de aplicar.

**Fuera de alcance:**

- Cualquier otro texto o elemento del login (formulario, botones, "Iniciar sesión", etc., que ya usan el tema).
- El fondo animado (`AnimatedLoginBackground`, SPEC 24) y sus colores.
- Estilos tipográficos (`AppTextStyles.eyebrow` / `AppTextStyles.h1`): se conservan, solo cambia el `color` del `copyWith`.
- Cambiar el texto en sí (sigue siendo `'LIBRO DE GASTOS'` y `'Mis gastos'`).

---

## Modelo de datos

_Esta feature no introduce ni modifica datos._ Solo cambia una referencia de color en dos widgets.

---

## Plan de implementación

1. En `login_screen.dart`, en el `Text('LIBRO DE GASTOS')`, reemplazar `.copyWith(color: AppPalette.dark.text)` por `.copyWith(color: context.palette.text)`. *Verificación:* `flutter analyze` limpio.
2. En el `Text('Mis gastos')`, hacer el mismo reemplazo. *Verificación:* `flutter analyze` limpio.
3. Actualizar el comentario de las líneas 84-85 para reflejar que ahora los títulos siguen el tema activo. *Verificación:* el comentario ya no menciona "se mantiene claro siempre".
4. Verificación visual: entrar al login en modo claro (los dos textos se ven oscuros y legibles) y en modo oscuro (se ven claros, sin regresión). *Verificación manual.*
5. `flutter analyze` limpio y `flutter test` verde.

---

## Criterios de aceptación

- [ ] `Text('LIBRO DE GASTOS')` usa `color: context.palette.text` (no `AppPalette.dark.text`).
- [ ] `Text('Mis gastos')` usa `color: context.palette.text` (no `AppPalette.dark.text`).
- [ ] En modo **claro**, ambos textos se ven oscuros y legibles sobre el fondo del login.
- [ ] En modo **oscuro**, ambos textos siguen viéndose claros (sin regresión).
- [ ] No se modificó ningún otro texto ni el fondo animado; los estilos `eyebrow`/`h1` se conservan.
- [ ] El comentario de las líneas 84-85 quedó actualizado.
- [ ] `flutter analyze` sin errores y `flutter test` en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Color de los títulos | Adaptativo `context.palette.text` | Oscuro fijo en ambos temas | El usuario pidió "como el resto de los textos del login", que ya son adaptativos; evita perder legibilidad en modo oscuro sobre el fondo oscuro. |
| Alcance | Solo esos dos textos | Revisar más elementos del login | Es un minor fix explícito; el resto ya respeta el tema. |

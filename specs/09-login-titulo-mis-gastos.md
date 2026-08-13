# 09 — Renombrar título del login "Gastos del mes" → "Mis gastos"

**Estado:** Implementado
**Dependencias:** spec 06 (background del login), spec 08 (registro/login)
**Fecha:** 2026-07-31
**Objetivo (una frase):** Cambiar el título visible de la pantalla de login de "Gastos del mes" a "Mis gastos".

---

## Alcance

**Incluye:**
- Reemplazar el texto `'Gastos del mes'` por `'Mis gastos'` en el título `h1` del login (`lib/features/auth/login_screen.dart:69`).

**No incluye:**
- El eyebrow `'LIBRO DE GASTOS'` (línea 67) se mantiene sin cambios.
- No se toca el estilo `AppTextStyles.h1` ni ningún otro texto de la app.
- No afecta al header de la pantalla principal (`home_screen.dart`), que ya muestra "Mis gastos" desde spec 03.
- No cambia el `title` de la MaterialApp en `main.dart` (`'Gastos del mes'`).

---

## Plan de implementación

1. **Renombrar el título del login.** En `lib/features/auth/login_screen.dart:69`, reemplazar `Text('Gastos del mes', style: AppTextStyles.h1)` por `Text('Mis gastos', style: AppTextStyles.h1)`. *Test manual:* abrir la pantalla de login y confirmar que el título muestra "Mis gastos".

---

## Criterios de aceptación

- [ ] La pantalla de login muestra el título **"Mis gastos"** (ya no "Gastos del mes").
- [ ] El eyebrow sigue mostrando **"LIBRO DE GASTOS"**.
- [ ] El estilo del título no cambia (sigue usando `AppTextStyles.h1`).
- [ ] Ningún otro texto de la app se ve afectado.

---

## Decisiones tomadas y descartadas

- **Solo se cambia el título del login, no el `title` de la MaterialApp ni el README.** Se descartó extender el rename a `main.dart:47` y a la documentación porque el pedido apunta únicamente al texto visible del login; el nombre interno de la app se mantiene como "Gastos del mes".
- **Se conserva el eyebrow "LIBRO DE GASTOS".** Da contexto de marca sobre el título y no formaba parte del pedido.

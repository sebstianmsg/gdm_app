# SPEC 07 — Confirmación al cerrar sesión

> **Estado:** Approved
> **Dependencias:** SPEC 03 (paleta morada / estructura de theme)
> **Fecha:** 2026-07-28
> **Objetivo:** Al tocar el botón de salir en el home, mostrar un `AlertDialog` de confirmación con opciones "Cancelar" y "Cerrar sesión" (destructiva), ejecutando el `logout()` solo si el usuario confirma.

---

## Alcance

**Dentro:**

1. **Interceptar el tap del botón de salir** en `home_screen.dart`. El `IconButton` del `_Header` deja de llamar directamente a `logout()`; ahora abre un `AlertDialog` de confirmación.

2. **`AlertDialog` de confirmación** con:
   - Título: **"¿Cerrar sesión?"**
   - Mensaje: **"Tu sesión se cerrará y volverás al login."**
   - Botón **"Cancelar"** (`TextButton` plano) → cierra el diálogo sin hacer nada.
   - Botón **"Cerrar sesión"** destacado en color destructivo/rojo → cierra el diálogo y ejecuta `ref.read(authProvider.notifier).logout()`.

3. **Flujo de confirmación:** el `logout()` solo se ejecuta si el usuario confirma. Al cancelar o descartar el diálogo (tap fuera / back), no pasa nada.

**Fuera de alcance (para futuros specs):**

- Confirmación en cualquier otro punto que dispare `logout()` (hoy solo existe el del home).
- Cambiar el ícono, posición o estilo del botón de salir.
- Rediseñar el diálogo con un estilo custom (bottom sheet, morado de marca, animaciones).
- Textos internacionalizados / i18n.
- Tests de widget para el diálogo.

---

## Modelo de datos

_Esta feature no introduce estructuras de datos ni estado persistente._ Solo agrega un flujo de UI (un diálogo) sobre la lógica de logout ya existente.

---

## Plan de implementación

1. **Extraer un método de confirmación en `home_screen.dart`.** Crear una función `Future<void> _confirmLogout(BuildContext context, WidgetRef ref)` (o helper equivalente) que muestre el `AlertDialog` con `showDialog<bool>` y actúe según la respuesta. *Test manual:* `flutter analyze` limpio.

2. **Construir el `AlertDialog`.** Título "¿Cerrar sesión?", contenido "Tu sesión se cerrará y volverás al login.", y `actions`: `TextButton` "Cancelar" (`Navigator.pop(ctx, false)`) y `TextButton`/`FilledButton` "Cerrar sesión" con color destructivo/rojo (`Navigator.pop(ctx, true)`). *Test manual:* el diálogo se ve con ambos botones y el de cerrar sesión destacado en rojo.

3. **Conectar el botón de salir al flujo.** Cambiar el `onLogout` del `_Header` para que, en vez de llamar `logout()` directo, dispare `_confirmLogout(...)`; solo si el resultado es `true` se ejecuta `ref.read(authProvider.notifier).logout()`. *Test manual:* tocar el botón abre el diálogo; "Cancelar" y tap fuera lo cierran sin cerrar sesión; "Cerrar sesión" cierra sesión y vuelve al login.

4. **Verificación integral.** `flutter analyze` limpio y `flutter test` verde. Recorrido manual: home → botón salir → cancelar (sigue en home) / confirmar (vuelve al login). *Test manual:* ambos caminos funcionan.

> Nota: `_Header` es hoy un `StatelessWidget` con callback `onLogout`. El diálogo se lanza desde el `home_screen` (que ya es `ConsumerWidget` con acceso a `ref` y `context`), manteniendo `_Header` sin cambios de tipo.

---

## Criterios de aceptación

- [ ] Al tocar el botón de salir del home ya **no** se cierra sesión de inmediato: se abre un `AlertDialog`.
- [ ] El diálogo muestra el título "¿Cerrar sesión?" y el mensaje "Tu sesión se cerrará y volverás al login.".
- [ ] El diálogo tiene un botón "Cancelar" en texto plano y un botón "Cerrar sesión" destacado en color destructivo/rojo.
- [ ] Tocar "Cancelar" cierra el diálogo y **no** ejecuta `logout()` (el usuario sigue en el home).
- [ ] Descartar el diálogo (tap fuera / botón atrás) tampoco ejecuta `logout()`.
- [ ] Tocar "Cerrar sesión" cierra el diálogo, ejecuta `ref.read(authProvider.notifier).logout()` y el usuario vuelve al login.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Tipo de confirmación | `AlertDialog` modal con "Cancelar" / "Cerrar sesión" | `showModalBottomSheet` deslizante / diálogo custom morado | Patrón estándar de Material, accesible y consistente; cambio mínimo. |
| Estilo del botón confirmar | "Cerrar sesión" destacado en color destructivo/rojo | Morado principal `#64009D` / ambos botones neutros | Señala visualmente que es la acción con consecuencia (perder la sesión). |
| Estilo del botón cancelar | `TextButton` plano | Botón con relleno | Jerarquía clara: la acción segura queda secundaria y sin peso visual. |
| Ubicación del método | En `home_screen.dart` (ya es `ConsumerWidget` con `ref`/`context`) | Mover la lógica a `_Header` o a un widget nuevo | `_Header` se mantiene `StatelessWidget` sin cambios de tipo; menor superficie de cambio. |
| Alcance del cambio | Solo el botón de salir del home | Interceptar cualquier disparador de `logout()` | Hoy el único punto que llama `logout()` desde la UI es ese botón. |
| Descarte del diálogo | Tap fuera / back **no** cierran sesión | `barrierDismissible: false` para forzar decisión explícita | Descartar equivale a cancelar; es el comportamiento esperado y menos intrusivo. |

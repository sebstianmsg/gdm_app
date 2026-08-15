# SPEC 26 — Más profundidad en modo oscuro (fondo y cards más claros y con más contraste)

> **Estado:** Implementado
> **Depende de:** SPEC 11 (theming dual `AppTheme`/`AppPalette`/`context.palette`)
> **Fecha:** 2026-08-15
> **Objetivo (una frase):** Aclarar sutilmente los tonos oscuros de la paleta dark (`bg`, `surface`, `card`, `surface2`) manteniendo el tinte morado, de modo que el fondo del `Scaffold` y las cards de la app (ruleta/gastos/home) tengan más contraste entre sí y ganen profundidad en vez de verse planos.

---

## Alcance

**Dentro:**

1. **Aclarar los cuatro tonos oscuros de `AppPalette.dark`** en `lib/theme/app_palette.dart`, manteniendo tinte morado y orden ascendente de claridad para dar profundidad:
   - `bg`: `#0B0610` → `#140A1F`
   - `surface`: `#180826` → `#1F1030`
   - `card`: `#1F0A30` → `#271438`
   - `surface2`: `#260C3A` → `#2E1A42`
2. Los hex son **propuesta inicial ajustable** en la verificación visual (igual que el SPEC 24 con la burbuja): si el contraste queda muy sutil o muy marcado, se afina el hex sin cambiar la estructura.
3. El cambio se propaga solo por el theming existente: `scaffoldBackgroundColor: palette.bg`, `CardTheme.color: palette.surface`, `InputDecoration.fillColor: palette.card`, etc. **No se toca ningún widget.**

**Fuera de alcance:**

- **Modo claro** (`AppPalette.light`): intacto.
- **Login** y su fondo animado (`AnimatedLoginBackground`, SPEC 24): intactos (usan sus propias constantes).
- El resto de tokens de la paleta oscura: `btn`, `btnHover`, `line`, `ink`, `alert`, `success`, `danger`, `text`, `textMuted`, `paper`: **sin cambios**.
- Sombras, bordes, elevaciones o `line` para reforzar la separación de cards: no se agregan (la profundidad viene solo del contraste de color).
- Cualquier cambio estructural de widgets, layouts o radios de card.

---

## Modelo de datos

_Esta feature no introduce ni modifica datos ni estado persistente._ Solo cambia el valor de cuatro constantes `Color` dentro de `AppPalette.dark`. Se documentan como referencia:

```dart
// AppPalette.dark — tonos oscuros aclarados (tinte morado, escala ascendente)
bg:       Color(0xFF140A1F), // antes #0B0610 — fondo del Scaffold
surface:  Color(0xFF1F1030), // antes #180826 — color de las cards
card:     Color(0xFF271438), // antes #1F0A30 — fills de inputs/chips
surface2: Color(0xFF2E1A42), // antes #260C3A — elevaciones/hover

// Sin cambios: btn, btnHover, line, ink, alert, success, danger, text, textMuted, paper
```

La escala mantiene el orden `bg < surface < card < surface2` en claridad, de modo que cada capa se despega de la anterior. El método `lerp` y `copyWith` de `AppPalette` no cambian: siguen operando sobre estos campos.

---

## Plan de implementación

Cada paso deja la app compilando y funcional.

1. **Aclarar `bg` y `surface` en `AppPalette.dark`.** En `lib/theme/app_palette.dart`, cambiar `bg` a `#140A1F` y `surface` a `#1F1030`. *Verificación:* `flutter analyze` limpio; en modo oscuro el fondo del Scaffold ya no se ve casi negro y las cards se despegan del fondo.

2. **Aclarar `card` y `surface2`.** Cambiar `card` a `#271438` y `surface2` a `#2E1A42`. *Verificación:* `flutter analyze` limpio; los fills de inputs/chips y las elevaciones mantienen la escala ascendente sin quedar pegados a `surface`.

3. **Verificación visual del contraste (modo oscuro).** Correr la app en tema oscuro y recorrer home → ruleta de gastos → cards de movimientos: las cards se distinguen claramente del fondo y la pantalla tiene profundidad, sin verse plana. *Verificación manual:* si el contraste queda muy sutil o muy marcado, afinar los hex conservando el orden `bg < surface < card < surface2`.

4. **Verificar que no hubo regresión en legibilidad.** Confirmar que `text` (`#FFFFFF`) y `textMuted` siguen legibles sobre los nuevos fondos, y que acentos (`ink`, `alert`, `success`) no chocan. *Verificación manual.*

5. **Verificar modo claro y login intactos.** Alternar a modo claro (SPEC 11) y entrar al login: sin cambios respecto de antes. *Verificación manual.*

6. **Verificación integral.** `flutter analyze` limpio y `flutter test` verde. *Verificación:* recorrido completo en ambos temas sin errores.

---

## Criterios de aceptación

- [ ] En `AppPalette.dark`: `bg == #140A1F`, `surface == #1F1030`, `card == #271438`, `surface2 == #2E1A42`.
- [ ] La escala mantiene el orden ascendente de claridad `bg < surface < card < surface2`.
- [ ] En modo **oscuro**, el fondo del `Scaffold` ya no se ve casi negro y las cards (home, ruleta de gastos, movimientos) se distinguen claramente del fondo: la pantalla tiene profundidad, no se ve plana.
- [ ] `text` (`#FFFFFF`) y `textMuted` siguen legibles sobre los nuevos fondos; los acentos (`ink`, `alert`, `success`, `danger`) no chocan.
- [ ] El resto de tokens de la paleta oscura (`btn`, `btnHover`, `line`, `ink`, `inkText`, `alert`, `success`, `danger`, `text`, `textMuted`, `paper`) quedaron sin cambios.
- [ ] `AppPalette.light` (modo claro) quedó intacto.
- [ ] El login y su fondo animado (`AnimatedLoginBackground`) quedaron intactos.
- [ ] No se modificó ningún widget: el cambio se propaga solo por el theming existente.
- [ ] `flutter analyze` sin errores y `flutter test` en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Tokens a ajustar | Aclarar los cuatro tonos oscuros como escala (`bg`, `surface`, `card`, `surface2`) | Tocar solo `bg` + `surface` (fondo y cards) | Ajustar la escala completa evita peldaños pegados o invertidos y mantiene coherencia entre inputs/chips/elevaciones y las cards. |
| Dirección del contraste | Fondo más claro **y** cards más claras aún (cards "flotan" por encima) | Cards hundidas (fondo más claro, cards iguales/más oscuras) | Es el patrón estándar de Material dark y el que da sensación de profundidad pedida por el usuario. |
| Magnitud del cambio | Salto sutil, con hex como propuesta ajustable en verificación visual | Salto marcado fijo | El usuario pidió "solo un poquito más claros"; dejar los hex afinables evita rehacer el spec si el contraste no convence a primera vista. |
| Tinte | Mantener el tinte morado de marca en los grises oscuros | Gris neutro puro | Coherencia con la identidad visual (acento `ink #64009D` y paleta morada del SPEC 11). |
| Cómo se logra la profundidad | Solo contraste de color entre capas | Agregar sombras, bordes o `line` para separar cards | El contraste de color alcanza para el objetivo y evita tocar widgets; agregar sombras es un cambio mayor no pedido. |
| Alcance de tema | Solo modo oscuro | Ajustar también modo claro y login | El usuario acotó explícitamente el pedido al modo oscuro dentro de la app. |

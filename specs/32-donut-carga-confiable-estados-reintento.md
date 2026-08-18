# SPEC 32 — El donut a veces tarda o no aparece sin recargar: carga confiable con estados de carga/vacío/error

> **Estado:** Implemented
> **Depende de:** SPEC 04 (donut responsive), SPEC 30 (efecto 3D), SPEC 01 (Supabase directo)
> **Fecha:** 2026-08-18
> **Objetivo (una frase):** Que el gráfico de torta aparezca de forma confiable al iniciar sesión o abrir la app, mostrando un estado de **cargando** distinguible del de **sin gastos**, y reintentando automáticamente el fetch inicial cuando falla, para eliminar la necesidad de recargar manualmente el dashboard.

---

## Alcance

**Dentro:**

1. **Estado de carga visible en el donut.** Mientras `expensesProvider(month)`/`categoriesProvider` cargan por primera vez (sin valor previo), el donut muestra un indicador de carga (spinner o skeleton) en lugar del anillo gris ambiguo.
2. **Estado "sin gastos" diferenciado.** Cuando la carga terminó con éxito pero no hay gastos ese mes, se mantiene el anillo gris con su texto de "sin categorías/gastos", claramente distinto del estado de carga.
3. **Estado de error con reintento automático.** Si el fetch inicial falla (queda `hasError`), reintentar automáticamente sin intervención del usuario; el pull-to-refresh existente se conserva como respaldo manual.
4. **Manejo de `hasError` en `home_screen.dart`.** Dejar de ignorar `expensesAsync.hasError` / `categoriesAsync.hasError` en el cálculo de estado (`home_screen.dart:43`).
5. **Coordinación de carreras entre providers.** Asegurar que el donut solo se considere "listo" cuando *ambos* providers (categorías y gastos) tengan valor, evitando el flash de vacío cuando uno llega antes que el otro.

**Fuera de alcance:**

- Instrumentar métricas/logging de tiempos de Supabase (descartado por el usuario en la definición).
- Cambiar el diseño visual del donut (radios, efecto 3D, colores, leyenda): SPEC 04/21/30 siguen intactas.
- Rediseñar el mecanismo de caché por mes de Riverpod o el flujo de restauración de sesión en `main.dart`.
- Precarga (prefetch) de gastos de meses no visitados.
- Cambiar el spinner/estado de la `MovementsCard` (ya muestra "Cargando…").

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Exponer un estado combinado en `home_screen.dart`.** Reemplazar el cálculo actual (`home_screen.dart:39-43`) por uno que derive tres estados explícitos del donut a partir de `categoriesAsync` y `expensesAsync`:
   - **cargando**: alguno de los dos `isLoading && !hasValue` (primera carga sin valor previo).
   - **error**: alguno tiene `hasError` y no hay valor previo utilizable.
   - **listo**: ambos tienen valor → se calcula `summaries` como hoy.
   Se conserva `valueOrNull ?? const []` para no romper el resto de la pantalla. *Verificación:* `flutter analyze` limpio; la home sigue renderizando con datos.

2. **Pasar el estado de carga/error al donut.** En `donut_card.dart`, agregar parámetros (p. ej. `isLoading`, `hasError`) o un enum de estado, y renderizar:
   - **cargando** → indicador de carga (spinner centrado o skeleton del anillo) en lugar del placeholder gris.
   - **sin gastos** (listo + `summaries` vacío) → anillo gris actual con su texto (comportamiento de hoy, intacto).
   - **listo con datos** → donut normal (SPEC 04/30 sin cambios).
   El botón "+" central (96×96) y la leyenda "Más detalles" se conservan según su condición actual. *Verificación:* visualmente se distingue cargando de sin-gastos; el "+" sigue centrado.

3. **Reintento automático del fetch inicial.** Cuando el estado combinado sea **error** en la primera carga, disparar un reintento automático de los providers afectados (invalidar/`refresh()` de `categoriesProvider` y/o `expensesProvider(month)`) una sola vez o con backoff acotado, sin que el usuario tenga que recargar. Evitar bucles infinitos si el error persiste (límite de reintentos → cae a un estado de error visible mínimo, con el pull-to-refresh como salida). *Verificación:* forzando un fallo de red inicial, el donut se recupera solo al restablecerse la conexión sin pull-to-refresh manual.

4. **Coordinar la carrera categorías/gastos.** Garantizar que el donut no muestre "sin gastos" mientras cualquiera de los dos providers siga en primera carga: hasta que ambos tengan valor, el estado es **cargando**. *Verificación:* al abrir la app, no aparece un flash de anillo gris/vacío antes de que lleguen los datos.

5. **Repaso visual e integración.** Probar en teléfono real (el caso reportado) y emulador, con arranque en frío tras login, reapertura de app, mes con gastos, mes sin gastos y con red lenta/caída inicial. *Verificación:* `flutter analyze` sin errores, `flutter test` en verde (sin regresiones en la home ni la card del donut), y el donut aparece sin necesidad de recargar.

---

## Criterios de aceptación

- [ ] Al iniciar sesión o abrir la app, mientras cargan los datos, el donut muestra un **indicador de carga** (spinner/skeleton), no el anillo gris ambiguo.
- [ ] El estado **"sin gastos este mes"** (carga exitosa, `summaries` vacío) se ve **distinto** del estado de carga y conserva el anillo gris con su texto.
- [ ] Si el **fetch inicial falla**, el donut **se recupera solo** (reintento automático) al restablecerse la conexión, **sin** que el usuario tenga que hacer pull-to-refresh.
- [ ] El reintento automático **no entra en bucle infinito**: tras un límite acotado cae a un estado de error visible, con el pull-to-refresh como salida manual.
- [ ] `home_screen.dart` **deja de ignorar** `hasError` de `categoriesAsync`/`expensesAsync` al calcular el estado del donut.
- [ ] No aparece un **flash de "sin gastos"/anillo gris** cuando categorías y gastos llegan en momentos distintos: el estado es "cargando" hasta que **ambos** tienen valor.
- [ ] El botón **"+" central (96×96)**, la leyenda "Más detalles", los radios y el efecto 3D (SPEC 04/21/30) quedan **sin cambios**.
- [ ] El pull-to-refresh existente sigue funcionando igual.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Qué produce la spec | **Diagnóstico + arreglo** de la carga del donut | Solo indicador de carga / solo diagnóstico | El usuario quiere que el donut aparezca confiable sin recargar, no solo verlo cargar. |
| Síntoma "hay que recargar" | **Reintento automático** del fetch inicial fallido | Solo botón "reintentar" / no cambiarlo | El usuario pidió que se resuelva solo, sin acción manual; el pull-to-refresh queda como respaldo. |
| Estado de carga vs. sin gastos | **Estados visuales distintos** (spinner vs. anillo gris) | Mantener el anillo gris para ambos | Hoy no se distingue "cargando" de "vacío"; el usuario quiere diferenciarlos. |
| Medición de rendimiento | **No instrumentar** tiempos/logging | Loggear tiempos de Supabase y primer render | El usuario decidió ir directo al arreglo sin métricas. |
| Coordinación de providers | **Estado combinado** (listo solo con ambos valores) | Dependencia dura `expenses`→`categories` en el provider | Un estado combinado en la UI evita reescribir la relación entre providers y el caché por mes. |
| Alcance del reintento | **Reintento acotado con límite** | Reintento infinito | Evita bucles y consumo de batería/datos si el error persiste. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| El reintento automático podría dispararse en bucle si el error es persistente (sin sesión, RLS, etc.). | Consumo de datos/batería, parpadeo del estado. | Límite de reintentos con backoff; tras el tope, estado de error visible + pull-to-refresh. |
| Si la demora real es del dispositivo/red del usuario, el spinner mejora la percepción pero no la velocidad. | El usuario sigue esperando, aunque con feedback claro. | El spinner comunica que está cargando; el reintento cubre los fallos. Se descartó medir tiempos por decisión del usuario. |
| Cambiar el cálculo de estado en `home_screen.dart` podría afectar a otras cards (movimientos/total). | Regresión en la home. | Conservar `valueOrNull ?? const []`; el estado combinado solo gobierna el donut. Verificar con `flutter test`. |
| El skeleton/spinner dentro de la caja del donut podría descuadrar el carrusel (`home_carousel.dart` re-mide altura). | Salto de layout al llegar los datos. | Mantener el indicador dentro del mismo `Size` del donut; verificar la re-medición del carrusel en el paso 5. |

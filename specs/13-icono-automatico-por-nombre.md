# 13 — Ícono automático de categoría por nombre

> **Estado:** Implementado
> **Dependencias:** spec 12 (columna `icon`, catálogo `kCategoryIcons`/`iconForKey`, editor de categoría con picker manual de "Símbolos")
> **Fecha:** 2026-08-01
> **Objetivo (una frase):** Que la app **sugiera/asigne automáticamente un ícono acorde al nombre** de la categoría (ej. "Nafta"→`gas`, "Farmacia"→`pill`), tanto al crear una categoría nueva como fallback en runtime para categorías viejas que hoy quedan en `help` (`?`), sin obligar a un UPDATE manual en la base y manteniendo la posibilidad de cambiar el ícono a mano.

---

## Contexto / problema

En spec 12 el ícono es un **dato persistido** (columna `icon`, default `'help'`) y se elige con un **picker manual**. Consecuencias observadas:

- Las categorías **creadas antes** de existir la columna `icon` quedaron con `'help'` (se ven con `?`) y solo se corrigen con un `UPDATE` manual por nombre sobre la DB.
- Al **crear** una categoría, si el usuario no toca "Símbolos", queda en `?`.

Spec 12 **descartó explícitamente** la autoasignación por keyword a favor del picker manual. Este spec **reintroduce** esa idea como una capa de sugerencia/fallback, sin quitar el picker manual.

---

## Alcance (propuesto — a definir en el diseño)

**Incluye (tentativo):**

1. **Diccionario keyword → clave de ícono** (en código), curado en español (ej. `nafta/combustible/gas → gas`, `farmacia/remedio → pill`, `super/almacen → basket`, `bondi/colectivo/subte → bus`, `médico/salud → heart`, etc.), con normalización (minúsculas, sin acentos) y match por palabra contenida.
2. **Sugerencia al crear/editar:** mientras se tipea el nombre en el editor, si el usuario **no eligió** ícono manualmente, preseleccionar el ícono sugerido por el nombre (el usuario siempre puede sobreescribirlo en "Símbolos").
3. **Fallback en runtime para `help`:** al renderizar una categoría cuyo `icon == 'help'`, si el nombre matchea el diccionario, mostrar el ícono sugerido **sin** tocar la DB (defensivo; no persiste salvo que el usuario guarde).
4. Mantener `help` como fallback final cuando no hay match.

**No incluye (tentativo):**

- Cambiar el catálogo de íconos del spec 12 (se reutiliza `kCategoryIcons`).
- Migraciones de datos obligatorias (el objetivo es evitar el UPDATE manual; si se persiste, que sea opt-in al editar/guardar).
- IA/NLP: es un diccionario de palabras clave, no inferencia semántica.

---

## Decisiones a resolver en el diseño

- ¿La sugerencia solo **preselecciona** en el editor (no persiste hasta "Guardar"), o también **persiste** automáticamente al crear?
- ¿El fallback en runtime para `help` es solo visual, o dispara una migración perezosa que guarda el ícono adivinado?
- Alcance del diccionario inicial (qué keywords en español cubrir) y cómo mantenerlo.
- Precedencia: ícono elegido a mano por el usuario **siempre** gana sobre la sugerencia.

---

## Criterios de aceptación (borrador)

- [ ] Existe un diccionario keyword→ícono con normalización (minúsculas/sin acentos) y match por contención de palabra.
- [ ] Al crear/editar, si el usuario no eligió ícono, el nombre sugiere un ícono acorde (ej. "Nafta"→`gas`), y el usuario puede sobreescribirlo.
- [ ] Una categoría con `icon == 'help'` cuyo nombre matchea muestra el ícono sugerido sin requerir cambios en la DB.
- [ ] Sin match, se mantiene `help` (`?`).
- [ ] El ícono elegido manualmente nunca es pisado por la sugerencia.
- [ ] `flutter analyze` sin errores y `flutter test` en verde.

---

## Notas

Surgió durante la implementación de spec 12 (feedback del usuario: las categorías default/viejas se veían con `?` y se pidió que tuvieran un ícono acorde automáticamente). Este spec cubre esa necesidad como capa de sugerencia/fallback, complementaria al picker manual ya existente.

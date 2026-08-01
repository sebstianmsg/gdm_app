# 12 — Categorías con íconos y rediseño

> **Estado:** Approved
> **Dependencias:** spec 01 (Supabase directo, `schema.sql`, trigger `handle_new_user`, `delete_category`), spec 02 (paleta de 32 colores y regla de "no repetir" en el selector), spec 11 (`AppPalette`/tema por contexto, `context.palette`)
> **Fecha:** 2026-08-01
> **Objetivo (una frase):** Rediseñar la gestión de categorías para que cada categoría tenga **color + ícono** (clave string persistida en una columna nueva `icon` de `categories`), con un modal de edición que incluye un **carrusel paginado de ~56 íconos Material relacionados con gastos personales** (8 por página) y el selector de "Color" (32 colores, regla no-repetir), una lista sin barra de scroll visible, y una fila de alta cuyo círculo muestra un **`+`**.

---

## Alcance

**Incluye:**

1. **Ícono por categoría (dato nuevo).**
   - Columna `icon text not null default 'help'` en `public.categories`.
   - Campo `icon` en el modelo `Category` (y su `fromJson`/`copyWith`).
   - Catálogo fijo de **~56 íconos** (claves string estables) mapeadas a `IconData` de Material, en `lib/features/categories/category_icons.dart`, **curado para representar gastos que puede tener una persona** (compras, comida, transporte, hogar, servicios, salud, ocio, educación, mascotas, etc.).

2. **Migración de datos.**
   - Snippet de migración: `ALTER TABLE` para agregar la columna; `UPDATE` que asigna ícono por match de nombre a las categorías existentes (`Transporte→bus`, `Comida→fork`, `Almacén→basket`, `Servicios→bolt`, `Salud→heart`, `Ocio→movie`, `Otros→help`) y deja `help` para el resto.
   - Actualizar el trigger `handle_new_user` para sembrar las 7 default **con su ícono**.
   - Actualizar `schema.sql` (consolidado) para reflejar la columna y el trigger nuevos.

3. **Rediseño visual de la lista de categorías** (`categories_modal.dart`):
   - Cada fila: círculo de color de 44px con el **ícono blanco** adentro + nombre + lápiz (✎, editar) + ✕ (borrar, solo si `isDeletable`).
   - Lista **scrolleable sin barra visible** (se oculta el scrollbar, se mantiene el scroll).

4. **Modal de edición de categoría** (abre al tocar el círculo o el lápiz de una fila): círculo color+ícono, input de nombre, sección **"Símbolos"** (carrusel paginado de 8 íconos por página con indicadores de punto y swipe horizontal; ~56 íconos → **7 páginas**), sección **"Color"** (paleta de 32 con regla no-repetir del spec 02, marcando el seleccionado), y botón **"Guardar"**.

5. **Alta de categoría** (fila inferior): círculo con un **`+`** (`Icons.add`) que abre el mismo editor para elegir ícono/color, input con placeholder **"Nombre de la categoría"**, botón **"Agregar"**. Al agregar se persiste `name`, `color` e `icon`.

**No incluye:**

- **Categorías sugeridas** (catálogo pre-armado que se agrega con un toque): **se descarta** de este spec; no hay sección "Sugeridas" ni archivo `suggested_categories.dart`.
- Mostrar el ícono de categoría **fuera** de la gestión de categorías (filas de gasto, leyenda del donut, chips en otras pantallas): el modelo lo soporta, pero su uso en otras vistas queda para otro spec.
- Cambiar la paleta de color o la regla de "no repetir" del spec 02 (se conservan los **32 colores** y el ocultamiento de usados).
- Íconos personalizados/subidos por el usuario o fuera de las ~56 claves del catálogo.
- Auto-asignación de ícono por el texto tipeado (keyword→ícono): se descarta a favor del picker manual.
- Cambios en `expenses` o en el cálculo de totales.

---

## Modelo de datos

Se introduce **un campo persistido nuevo** (`icon`) y **un catálogo en código** (íconos). Ya **no** hay catálogo de sugeridas. No se tocan `expenses` ni el cálculo de totales.

### Columna nueva en `public.categories`

| Columna | Tipo | Null | Default | Significado |
|---|---|---|---|---|
| `icon` | `text` | NOT NULL | `'help'` | Clave string del catálogo fijo de íconos. `'help'` es el fallback (interrogante). |

- La clave se compara/guarda en **minúsculas** y siempre pertenece al catálogo. Si llegara un valor desconocido desde la DB, la UI lo renderiza como `help` (fallback defensivo).

### Modelo `Category` (Dart)

```dart
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,        // nuevo
    required this.isDeletable,
  });

  final String id;
  final String name;
  final String color;         // hex '#RRGGBB'
  final String icon;          // clave del catálogo (ej. 'cart'); fallback 'help'
  final bool isDeletable;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String,
    icon: (json['icon'] as String?) ?? 'help',   // tolera filas sin icon
    isDeletable: json['is_deletable'] as bool,
  );

  Category copyWith({String? name, String? color, String? icon}) => Category(
    id: id, name: name ?? this.name, color: color ?? this.color,
    icon: icon ?? this.icon, isDeletable: isDeletable,
  );
}
```

La capa `categories_data.dart` incluye `icon` al crear (`insert`) y actualizar (`update`).

### Catálogo de íconos (constante en código)

`lib/features/categories/category_icons.dart` — mapa `String → IconData` (Material Icons) con **56 claves** curadas por tipo de gasto (el orden define las **7 páginas** del carrusel, 8 por página), más `iconForKey` con fallback:

```dart
const kCategoryIcons = <String, IconData>{
  // Compras y dinero
  'cart': Icons.shopping_cart,   'basket': Icons.shopping_basket,
  'bag': Icons.shopping_bag,     'store': Icons.store,
  'wallet': Icons.account_balance_wallet, 'bank': Icons.account_balance,
  'card': Icons.credit_card,     'savings': Icons.savings,
  // Comida y bebida
  'fork': Icons.restaurant,      'fastfood': Icons.fastfood,
  'pizza': Icons.local_pizza,    'coffee': Icons.local_cafe,
  'bar': Icons.local_bar,        'cake': Icons.cake,
  'grocery': Icons.local_grocery_store, 'icecream': Icons.icecream,
  // Transporte
  'bus': Icons.directions_bus,   'car': Icons.directions_car,
  'gas': Icons.local_gas_station,'train': Icons.train,
  'subway': Icons.subway,        'taxi': Icons.local_taxi,
  'bike': Icons.directions_bike, 'parking': Icons.local_parking,
  // Viajes
  'plane': Icons.flight,         'hotel': Icons.hotel,
  'luggage': Icons.luggage,      'beach': Icons.beach_access,
  // Hogar y servicios
  'home': Icons.home,            'bolt': Icons.bolt,
  'water': Icons.water_drop,     'fire': Icons.local_fire_department,
  'wifi': Icons.wifi,            'phone': Icons.smartphone,
  'tv': Icons.tv,                'cleaning': Icons.cleaning_services,
  // Salud
  'heart': Icons.favorite,       'medical': Icons.medical_services,
  'pill': Icons.medication,      'hospital': Icons.local_hospital,
  'spa': Icons.spa,              'muscle': Icons.fitness_center,
  // Ocio
  'movie': Icons.movie,          'music': Icons.music_note,
  'game': Icons.sports_esports,  'sports': Icons.sports_soccer,
  'camera': Icons.photo_camera,  'book': Icons.menu_book,
  // Educación, trabajo, personal
  'school': Icons.school,        'work': Icons.work,
  'build': Icons.build,          'gift': Icons.card_giftcard,
  'paw': Icons.pets,             'child': Icons.child_care,
  'checkroom': Icons.checkroom,  'help': Icons.help_outline,
};

IconData iconForKey(String key) => kCategoryIcons[key] ?? Icons.help_outline;
```

> 56 claves = 7 páginas exactas de 8. `help` queda como último slot y como fallback de claves desconocidas.

---

## Plan de implementación

Cada paso deja el sistema compilando y funcional.

1. **Migración de la DB (SQL).** Snippet: `ALTER TABLE public.categories ADD COLUMN icon text NOT NULL DEFAULT 'help';` seguido de `UPDATE`s por nombre para las categorías existentes (`Transporte→bus`, `Comida→fork`, `Almacén→basket`, `Servicios→bolt`, `Salud→heart`, `Ocio→movie`, `Otros→help`). *Verificación:* correr sobre la DB deja todas las filas con un `icon` no nulo y coherente.

2. **Actualizar `schema.sql` (consolidado).** Agregar la columna `icon` a `categories` y actualizar el `insert` del trigger `handle_new_user` para sembrar las 7 default con su ícono. *Verificación:* correr el schema sobre una DB limpia crea la columna y siembra las 7 con ícono; `delete_category` sigue intacto.

3. **Modelo `Category` + capa de datos.** Agregar `icon` al modelo (`fromJson` con fallback `'help'`, `copyWith`) e incluir `icon` en `insert`/`update` de `categories_data.dart`. *Verificación:* `flutter analyze` limpio; test de mapeo `fromJson` con y sin `icon`.

4. **Catálogo de íconos.** Crear/actualizar `lib/features/categories/category_icons.dart` con `kCategoryIcons` (56 claves → `IconData`) y `iconForKey` con fallback. *Verificación:* `iconForKey('cart')` devuelve `Icons.shopping_cart`; `iconForKey('xxx')` devuelve `Icons.help_outline`.

5. **`categoriesProvider` — soporte de `icon`.** Extender `create`/`updateCategory` para aceptar y propagar `icon`. *Verificación:* crear/editar una categoría persiste el ícono y se refleja al recargar.

6. **Rediseño de la lista (`categories_modal.dart`).** Filas con círculo de 44px (color de fondo + `Icon(iconForKey(c.icon), color: Colors.white)`), nombre, lápiz (editar) y ✕ (borrar si `isDeletable`). Ocultar la barra de scroll (envolver con `ScrollConfiguration` sin scrollbar) manteniendo el scroll. *Verificación manual:* la lista muestra íconos y se desplaza sin barra visible.

7. **Modal de edición de categoría.** Nuevo modal (abre al tocar el círculo o el lápiz de una fila) con círculo color+ícono, input de nombre, sección "Símbolos" (paso 8), sección "Color" (paso 9) y botón "Guardar". Al guardar, `updateCategory(id, name, color, icon)`. *Verificación manual:* editar una categoría cambia nombre, ícono y color y persiste.

8. **Carrusel de "Símbolos".** `PageView` de páginas de 8 íconos (grid 4×2) con indicadores de punto y swipe horizontal; el ícono seleccionado se resalta con el color elegido, el resto con fondo translúcido. **56 íconos → 7 páginas.** *Verificación manual:* los 56 íconos repartidos en 7 páginas; seleccionar uno lo marca; los dots reflejan la página.

9. **Sección "Color" en el modal.** Reutilizar la paleta de 32 y la regla de no-repetir del spec 02 (swatches, tilde/anillo en el seleccionado, oculta usados salvo el propio al editar). *Verificación manual:* al editar, el color propio aparece marcado; los usados por otras no aparecen.

10. **Alta de categoría (fila inferior).** Círculo con **`+` (`Icons.add`)** que abre el editor (paso 7) para elegir ícono/color del borrador, input con placeholder **"Nombre de la categoría"**, botón "Agregar" que persiste `name`/`color`/`icon`. Mantener el manejo de "No hay colores libres" y el error de nombre vacío. *Verificación manual:* el círculo de alta muestra un `+`; agregar una categoría con ícono y color elegidos la crea y limpia el borrador.

11. **Limpieza de "Sugeridas".** Eliminar el archivo `lib/features/categories/suggested_categories.dart` (si existe) y toda referencia a la sección "Sugeridas" en `categories_modal.dart`. *Verificación:* `flutter analyze` sin referencias colgantes; no hay sección "Sugeridas" en el modal.

12. **Repaso e integración.** `flutter analyze` limpio, `flutter test` verde (mapeo de `Category` y tests que construyan `Category` sin `icon`). Recorrido visual del modal en tema claro y oscuro (spec 11). *Verificación:* suite en verde y sin regresiones visuales.

---

## Criterios de aceptación

- [ ] `public.categories` tiene una columna `icon text not null default 'help'`; el snippet de migración deja a las categorías existentes con un ícono coherente por nombre (`Transporte→bus`, `Comida→fork`, `Almacén→basket`, `Servicios→bolt`, `Salud→heart`, `Ocio→movie`, `Otros→help`) y `help` para el resto.
- [ ] `schema.sql` (consolidado) refleja la columna `icon` y el trigger `handle_new_user` siembra las 7 categorías default **con su ícono**.
- [ ] Correr `schema.sql` sobre una DB limpia crea la columna y siembra las 7 con ícono; `delete_category` sigue funcionando (reasigna a "Otros").
- [ ] `Category` tiene el campo `icon`; `Category.fromJson` sin `icon` cae en `'help'`; `copyWith` permite cambiar `icon`.
- [ ] `categories_data.dart` envía `icon` en `insert` y `update`.
- [ ] Existe `kCategoryIcons` con **56 claves** mapeadas a `IconData`, y `iconForKey` devuelve `Icons.help_outline` para claves desconocidas.
- [ ] Los íconos del catálogo están **curados por tipo de gasto** (compras, comida, transporte, viajes, hogar/servicios, salud, ocio, educación/trabajo/personal).
- [ ] Cada fila de la lista muestra un círculo con el color de la categoría y su ícono en blanco, el nombre, el lápiz (editar) y la ✕ de borrar (solo si `isDeletable`).
- [ ] La lista de categorías se desplaza **sin barra de scroll visible**.
- [ ] Tocar el círculo o el lápiz de una fila abre el modal de edición con nombre, "Símbolos" y "Color"; guardar persiste nombre, ícono y color.
- [ ] "Símbolos" es un carrusel paginado (8 por página, **7 páginas**) con swipe e indicadores de punto; el ícono seleccionado queda resaltado y los dots reflejan la página actual.
- [ ] La sección "Color" conserva la paleta de 32 y la regla de no-repetir del spec 02 (oculta usados; el color propio sigue visible y marcado al editar).
- [ ] El círculo de la fila de alta muestra un **`+`**; la fila usa el placeholder exacto **"Nombre de la categoría"**; permite elegir ícono/color y crea la categoría con los tres valores.
- [ ] Se mantiene el manejo de "No hay colores libres" y el error de nombre vacío al crear.
- [ ] **No** existe sección "Sugeridas" en el modal ni el archivo `suggested_categories.dart`.
- [ ] `flutter analyze` no reporta errores y `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Categorías sugeridas | **Descartadas** (no hay sección "Sugeridas") | Catálogo pre-armado que se agrega con un toque | Al usuario no le convenció; ensuciaba el modal. El picker manual de ícono/color cubre el alta. |
| Cantidad de íconos | **56 íconos** (7 páginas) | 24 íconos (versión previa) | Más variedad para representar distintos gastos personales sin volver interminable el swipe. |
| Curaduría del set | Íconos **elegidos por tipo de gasto** (compras, comida, transporte, viajes, hogar, salud, ocio, etc.) | Set genérico sin criterio | El ícono debe sugerir de un vistazo el tipo de gasto de la categoría. |
| Ícono de la fila de alta | **`+` (`Icons.add`)** en el círculo | Mantener el `?`/`help` | El `+` comunica "agregar"; el `?` no dejaba claro que era el alta. |
| Paleta de color | **Mantener 32 + no repetir** (spec 02) | Ampliar a 48/64 colores | Ícono y color son independientes; ampliar íconos no obliga a más colores y no hay conflicto real con la regla de no-repetir. |
| Asignación de ícono | **Picker manual** (carrusel) | Auto-asignar por keyword del nombre | Sin adivinar por texto; el usuario elige. |
| Set de íconos | **Material Icons** con clave string en DB | Portar SVG custom | Nativos de Flutter, sin assets ni mantenimiento de paths; la clave string es estable y liviana. |
| Persistencia del ícono | Columna `icon` en `categories` (default `'help'`) | Guardar solo en cliente / inferir en runtime | El ícono es parte del dato; debe sobrevivir entre sesiones y dispositivos. |
| Migración de filas viejas | `UPDATE` por match de nombre + `help` de fallback | Dejar todo en `help` hasta editar | Las 7 default y nombres comunes quedan bien de entrada. |
| Picker de "Símbolos" | **Carrusel paginado con puntitos** (swipe) | Grid simple scrolleable | Fidelidad al mockup aprobado; con 56 íconos las páginas ordenan por tema. |
| Scroll de la lista | **Ocultar scrollbar, mantener scroll** | Sin scroll | Con 7+ categorías el scroll es necesario; solo se oculta la barra. |
| Fallback de ícono | `'help'` (interrogante) ante clave desconocida | Fallar / mostrar vacío | Defensivo ante datos viejos o claves fuera del catálogo. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| La migración corre en una DB con datos y alguna categoría queda con ícono incoherente (nombre no matcheado). | Bajo | `default 'help'` garantiza no-nulo; los `UPDATE` por nombre cubren las 7 default y nombres comunes; el resto queda en `help` y es editable con un toque. |
| Filas viejas o de otra fuente traen un `icon` fuera del catálogo de 56. | Bajo | `Category.fromJson` e `iconForKey` caen en `'help'`; la UI nunca rompe por una clave desconocida. |
| Tests existentes construyen `Category` sin el nuevo campo `icon` y dejan de compilar. | Medio | Actualizar los constructores en tests; `icon` es `required`, así el compilador señala cada punto a ajustar. |
| El carrusel `PageView` dentro de un modal desplazable compite con el scroll vertical del sheet. | Medio | El `PageView` es de swipe **horizontal** y alto acotado; se prueba el gesto en el paso 8 para que no capture el scroll vertical del modal. |
| Con 7 páginas de íconos, el swipe se vuelve largo para llegar al final. | Bajo | El orden agrupa por tema (compras, comida, transporte…) para ubicar rápido; los dots dan sentido de posición. |
| Ocultar el scrollbar deja sin pista visual de que hay más categorías. | Bajo | Se mantiene el scroll y el corte visual de la última fila insinúa continuidad; aceptado como parte del diseño de referencia. |
| Migración vs `schema.sql`: aplicar ambos genera confusión sobre qué correr. | Bajo | El snippet de migración es para DBs existentes; `schema.sql` es para DB limpia. Se documenta cuál usar en cada caso. |
| Quedan restos de "Sugeridas" (archivo o referencias) tras eliminarla. | Bajo | Paso 11 dedicado a la limpieza; `flutter analyze` detecta referencias colgantes. |

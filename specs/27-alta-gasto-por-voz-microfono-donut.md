# SPEC 27 — Alta de gasto por voz (micrófono flotante sobre el donut)

> **Estado:** Implementado
> **Depende de:** SPEC 12/13 (`detectCategoryName`, catálogo de categorías), SPEC 04/21 (card del donut), SPEC 11 (theming `context.palette`)
> **Fecha:** 2026-08-16
> **Objetivo (una frase):** Agregar un micrófono flotante en la esquina inferior derecha de la card del donut que, usando el reconocimiento de voz **nativo y gratuito** del dispositivo, escuche una frase como "gasté 3000 pesos en el súper", extraiga monto, descripción y categoría de forma local, y abra el sheet de "Agregar gasto" pre-llenado para que el usuario confirme.

**Nota de costo:** se usa el paquete `speech_to_text`, que delega en el motor de voz del sistema operativo (Android `SpeechRecognizer` / iOS Speech). No hay API paga ni costo por uso. El parseo del texto es 100% local (regex + tu diccionario `categoryKeywords`).

---

## Alcance

**Dentro:**

1. **Dependencia `speech_to_text`** en `pubspec.yaml` (motor de voz nativo del SO, gratis) y permisos de micrófono/reconocimiento en `AndroidManifest.xml` (`RECORD_AUDIO`) e `Info.plist` (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`).
2. **Botón de micrófono flotante** en la esquina inferior derecha de la card "Por categoría" (`DonutCard`), superpuesto sobre el donut, al alcance del pulgar. Convive con el botón `+` central existente (que sigue abriendo el alta manual).
3. **Overlay "Escuchando…"** animado al tocar el mic: muestra estado de escucha y el texto transcripto en vivo; se cierra al terminar el dictado.
4. **Parser local de la frase** (`lib/utils/voice_expense_parser.dart`): extrae el **monto** (primer número de la frase, tolerando "pesos", separadores de miles y decimales con coma), la **descripción** (frase transcripta sin el monto ni "pesos") y la **categoría** (reusando `detectCategoryName` sobre toda la frase).
5. **Sheet de alta pre-llenado:** al terminar el dictado se abre `showAddExpenseSheet` con monto/descripción/categoría precargados; el usuario revisa y toca "Agregar". Se extiende el form para aceptar valores iniciales.
6. **Casos degradados:** si no se detecta el monto, se abre igual el sheet con lo que sí se detectó y el campo monto vacío. Si se niega el permiso de micrófono, se muestra un aviso y se ofrece abrir el alta manual normal.
7. **Idioma:** reconocimiento en el locale del dispositivo (default de `speech_to_text`).

**Fuera de alcance:**

- **Motores de voz pagos / en la nube** (Whisper, Google Cloud Speech, etc.): no se usan.
- **NLP / IA semántica:** el parseo es regex + diccionario de keywords, no inferencia.
- **Múltiples gastos en una sola frase** (ej. "gasté 3000 en el súper y 500 en el bondi"): solo se toma el primer gasto.
- **Fecha por voz** (ej. "ayer", "el lunes"): la fecha queda en "hoy" por default, editable en el sheet como siempre.
- **Alta de gasto compartido por voz** (`shared_expense_form`): solo aplica al alta de gasto normal.
- **Plataforma web:** el foco es móvil (Android/iOS); en web queda best-effort sin garantía.
- Cambios en el catálogo de categorías, el diccionario `categoryKeywords` o el botón `+` existente.

---

## Modelo de datos

_Esta feature **no introduce ni modifica datos ni estado persistente.**_ El gasto se guarda por el camino existente (`expensesProvider.create` → tabla `expenses`), sin columnas nuevas. Solo aparece una **estructura transitoria en memoria** que devuelve el parser, para pasar del texto reconocido al sheet pre-llenado. Se documenta como referencia:

```dart
// lib/utils/voice_expense_parser.dart
class ParsedVoiceExpense {
  const ParsedVoiceExpense({
    required this.amount,        // double? — null si no se detectó monto
    required this.description,   // String  — frase sin el monto ni "pesos"
    required this.categoryName,  // String? — null si ningún keyword matchea
  });

  final double? amount;
  final String? description;
  final String? categoryName;
}

/// Parsea la frase transcripta. Nunca lanza: si algo no matchea, ese campo
/// queda null / vacío y el caller abre el sheet con lo que haya.
ParsedVoiceExpense parseVoiceExpense(String transcript);
```

- **`amount`**: primer número de la frase; tolera "pesos", `$`, separador de miles (`.` o espacio) y decimal con coma (`3.000` → 3000, `1500,50` → 1500.5).
- **`categoryName`**: resultado de `detectCategoryName(transcript)`; el caller lo cruza contra las categorías reales del usuario (por nombre, case-insensitive) para obtener el `categoryId`, con fallback a la primera categoría / "Otros" si no hay match.
- **`description`**: `transcript` con el monto y las palabras "pesos"/`$` removidas y recortado (ej. "gasté 3000 pesos en el súper" → "gasté en el súper").

---

## Plan de implementación

Cada paso deja la app compilando y funcional.

1. **Agregar dependencia y permisos.** Añadir `speech_to_text` a `pubspec.yaml` (`flutter pub get`). Agregar `RECORD_AUDIO` en `android/app/src/main/AndroidManifest.xml`, y `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription` en `ios/Runner/Info.plist`. *Verificación:* `flutter analyze` limpio; la app sigue arrancando.

2. **Parser local `parseVoiceExpense`.** Crear `lib/utils/voice_expense_parser.dart` con `ParsedVoiceExpense` y la función pura del modelo de datos (monto por regex, descripción sin monto, categoría vía `detectCategoryName`). *Verificación:* tests unitarios del parser en verde (varias frases de ejemplo).

3. **Servicio de voz `VoiceInputService`.** Crear `lib/services/voice_input.dart` que envuelva `speech_to_text`: `initialize()` (pide permiso), `listen(onResult)`, `stop()`, y expone estados (disponible / escuchando / permiso denegado). *Verificación:* `flutter analyze` limpio; se puede iniciar/detener escucha en un dispositivo real.

4. **Overlay "Escuchando…".** Crear el widget del overlay animado que muestra el estado de escucha y el texto parcial transcripto en vivo, y se cierra al finalizar. *Verificación manual:* al invocarlo aparece la animación y refleja el texto reconocido.

5. **Extender el sheet de alta para valores iniciales.** En `lib/features/expenses/expense_form.dart`, agregar parámetros opcionales `initialDescription`, `initialAmount`, `initialCategoryId` a `showAddExpenseSheet` / `_AddExpenseForm`, precargando los controllers y el dropdown. Sin romper las llamadas actuales (todos opcionales). *Verificación:* el alta manual desde el botón `+` sigue igual; llamando con valores iniciales el form abre pre-llenado.

6. **Botón de micrófono flotante en `DonutCard`.** Agregar un callback `onVoicePressed` a `DonutCard` y ubicar un botón circular flotante en la esquina inferior derecha del `Stack` del donut. *Verificación manual:* el mic aparece abajo a la derecha del donut, al alcance del pulgar, sin tapar el botón `+`.

7. **Cablear el flujo completo en `home_screen.dart`.** Al tocar el mic: inicializar el servicio, mostrar el overlay, escuchar; al terminar, correr `parseVoiceExpense`, resolver el `categoryId` contra las categorías reales, y abrir `showAddExpenseSheet` pre-llenado que en "Agregar" llama a `expensesProvider(month).create(...)`. *Verificación manual:* dictar "gasté 3000 pesos en el súper" abre el sheet con monto 3000, descripción y categoría Almacén; al confirmar, el gasto aparece en el mes.

8. **Casos degradados.** Sin monto detectado → sheet con monto vacío. Permiso denegado → aviso + opción de abrir el alta manual. Sin match de categoría → primera categoría / "Otros" editable. *Verificación manual:* cada caso se comporta según lo definido, sin crashear.

9. **Verificación integral.** `flutter analyze` limpio y `flutter test` verde; recorrido en dispositivo real (Android e iOS si hay) del flujo feliz y los degradados. *Verificación:* todos los criterios de aceptación cumplidos.

---

## Criterios de aceptación

- [ ] `pubspec.yaml` incluye `speech_to_text`; no se agregó ninguna dependencia de motor de voz pago ni servicio en la nube.
- [ ] Android declara `RECORD_AUDIO`; iOS declara `NSMicrophoneUsageDescription` y `NSSpeechRecognitionUsageDescription`.
- [ ] Existe `parseVoiceExpense(String)` que devuelve `ParsedVoiceExpense` y nunca lanza; con "gasté 3000 pesos en el súper" devuelve `amount == 3000`, `categoryName` que matchea Almacén y una `description` sin el monto ni "pesos".
- [ ] El parser tolera separador de miles (`3.000` → 3000) y decimal con coma (`1500,50` → 1500.5).
- [ ] La card "Por categoría" muestra un botón de micrófono flotante en la esquina inferior derecha del donut, al alcance del pulgar, sin tapar el botón `+` central.
- [ ] Al tocar el mic aparece un overlay "Escuchando…" animado que refleja el texto transcripto en vivo y se cierra al terminar el dictado.
- [ ] Al terminar el dictado se abre el sheet "Agregar gasto" pre-llenado con monto, descripción y categoría detectados; al tocar "Agregar" el gasto se persiste vía el flujo existente y aparece en el mes.
- [ ] Si no se detecta monto, el sheet se abre igual con lo detectado y el campo monto vacío para completar a mano.
- [ ] Si el usuario niega el permiso de micrófono, se muestra un aviso y se ofrece abrir el alta manual; la app no crashea.
- [ ] Si ningún keyword matchea, la categoría cae en la primera / "Otros" y queda editable en el sheet.
- [ ] El botón `+` central y el alta manual siguen funcionando exactamente igual que antes.
- [ ] `flutter analyze` sin errores y `flutter test` en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Motor de voz | `speech_to_text` (reconocimiento nativo del SO, gratis) | Whisper / Google Cloud Speech / OpenAI (pagos) | El usuario pidió explícitamente no pagar extra; el motor nativo cubre el caso sin costo por uso. |
| Interpretación de la frase | Parseo local (regex para monto + diccionario `categoryKeywords`) | NLP / IA semántica | Evita costo y dependencia externa; reusa la lógica de detección ya existente (SPEC 12/13). |
| Tras reconocer la voz | Abrir sheet pre-llenado para confirmar | Guardar directo (con o sin "deshacer") | El reconocimiento de voz falla seguido; la revisión evita gastos mal cargados. |
| Monto no detectado | Abrir sheet con lo detectado y monto vacío | Avisar y descartar el dictado | No se pierde el trabajo del dictado; el usuario solo completa el monto. |
| Categoría | Reusar `detectCategoryName` sobre toda la frase | Extraer solo lo que sigue a "en" | Más robusto: no depende de que el usuario diga "en"; aprovecha el diccionario existente. |
| Descripción | Frase transcripta sin el monto ni "pesos" | Frase completa / nombre de categoría | Descripción útil y editable, sin ruido del número. |
| Ubicación del mic | Flotante sobre la card del donut (inferior derecha) | FAB global de Scaffold | El usuario pidió que esté sobre el gráfico de torta, al alcance del pulgar. |
| Feedback de escucha | Overlay "Escuchando…" animado con texto en vivo | Solo cambiar el ícono del mic | Da confianza de que está grabando y muestra qué entendió antes de confirmar. |
| Permiso denegado | Aviso + fallback al alta manual | Solo mensaje de error | No deja al usuario sin alternativa para cargar el gasto. |
| Idioma | Locale del dispositivo (default de `speech_to_text`) | Español fijo (es-*) | Elección del usuario; usa la configuración del teléfono. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| **Precisión del reconocimiento nativo variable** entre dispositivos/idiomas (nombres locales, ruido). | El monto o la categoría salen mal. | El sheet siempre es un paso de revisión editable; nada se guarda sin confirmar. |
| **Locale del dispositivo no en español** (por la decisión de usar el idioma del teléfono). | La transcripción puede venir en otro idioma y no matchear keywords en español. | La categoría cae en "Otros"/primera, editable; el monto (número) sigue detectándose igual. Queda documentado como limitación conocida. |
| **`speech_to_text` no disponible / motor de voz ausente** en algunos Android sin servicios de Google. | El mic no funciona. | `initialize()` detecta disponibilidad; si no está, se avisa y se ofrece el alta manual. |
| **Ambigüedad del monto** (frases con varios números, ej. "3 paquetes de 500"). | Se toma un número equivocado. | Regla clara: primer número de la frase; el usuario corrige en el sheet. |
| **Permisos mal declarados en iOS** hacen rechazar la app en App Store o crashear al pedir micrófono. | Bloqueo de release. | Paso 1 declara las tres claves de uso requeridas; se verifica en dispositivo real. |
| **Superposición visual** del mic con el botón `+` o la leyenda en pantallas chicas. | Toque accidental. | Posicionar el mic en el `Stack` con margen; verificación manual en pantallas chicas (paso 6). |

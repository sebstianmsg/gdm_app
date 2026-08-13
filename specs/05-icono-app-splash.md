# 05 — Ícono de app y splash logo

**Estado:** Implementado
**Fecha:** 2026-07-27
**Dependencias:** SPEC 03 (paleta morada `#64009D`)

**Objetivo (una frase):** Configurar el ícono de la aplicación y la pantalla de splash usando los paquetes `flutter_launcher_icons` y `flutter_native_splash`, a partir de `resources/art/icon.png` (1024×1024) y `resources/art/splash_logo.png` (1152×1152), con ícono adaptativo Android sobre fondo `#64009D`, splash con logo blanco sobre fondo `#64009D` y soporte para Android 12+, generando además las carpetas del resto de plataformas para dejarlas listas.

---

## Alcance

**Dentro:**

1. **Dependencias de herramientas.** Agregar `flutter_launcher_icons` y `flutter_native_splash` a `dev_dependencies` en `pubspec.yaml`.

2. **Crear el resto de plataformas.** Ejecutar `flutter create --platforms=ios,web,windows,macos,linux .` para generar las carpetas faltantes (hoy solo existe `android/`), de modo que ícono y splash puedan generarse también ahí y queden listas para más adelante.

3. **Configuración del ícono de app (`flutter_launcher_icons`).**
   - Fuente: `resources/art/icon.png` (1024×1024).
   - Ícono legacy para todas las plataformas donde aplique.
   - **Ícono adaptativo Android:** `adaptive_icon_foreground` = `icon.png`, `adaptive_icon_background` = `#64009D`.
   - Generar los recursos y sobrescribir los íconos por defecto de Flutter.

4. **Configuración del splash (`flutter_native_splash`).**
   - Imagen: `resources/art/splash_logo.png` (1152×1152).
   - Color de fondo: `#64009D`.
   - **Soporte Android 12+** (`android_12:`) con el mismo logo y color de fondo.
   - Generar los recursos de splash para las plataformas soportadas.

5. **Regeneración por CLI.** Correr `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create` para producir los recursos, dejando los assets generados versionados.

**Fuera de alcance (para futuros specs):**

- Rediseño de las imágenes `icon.png` / `splash_logo.png` (se usan tal cual vienen).
- Animaciones de splash o splash con lógica (barra de carga, transiciones custom).
- Íconos temáticos de Android 13 (monochrome) más allá del adaptativo estándar.
- Ajustes de branding en tiendas (screenshots, feature graphic, etc.).
- Cualquier cambio de UI dentro de la app (pantallas, colores in-app ya cubiertos por SPEC 03).

---

## Plan de implementación

1. **Crear las plataformas faltantes.** Ejecutar `flutter create --platforms=ios,web,windows,macos,linux .` en la raíz. Deja intacta la carpeta `android/` existente y agrega `ios/`, `web/`, `windows/`, `macos/`, `linux/`. *Test manual:* aparecen las carpetas nuevas y `flutter analyze` sigue limpio.

2. **Agregar las dependencias de herramientas.** Añadir `flutter_launcher_icons` y `flutter_native_splash` a `dev_dependencies` en `pubspec.yaml` y correr `flutter pub get`. *Test manual:* `flutter pub get` resuelve sin conflictos.

3. **Configurar `flutter_launcher_icons`.** Agregar la sección de configuración (en `pubspec.yaml` bajo `flutter_launcher_icons:`) con:
   - `image_path: resources/art/icon.png`
   - `android: true`, `ios: true`, `web`/`windows`/`macos` habilitados según soporte del paquete.
   - `adaptive_icon_foreground: resources/art/icon.png`
   - `adaptive_icon_background: "#64009D"`
   *Test manual:* la config es válida (paso siguiente no falla).

4. **Generar los íconos.** Ejecutar `dart run flutter_launcher_icons`. *Test manual:* se sobrescriben los `mipmap-*` de Android (y recursos de las otras plataformas) con el nuevo ícono; al instalar la app el launcher muestra el ícono morado con el logo blanco.

5. **Configurar `flutter_native_splash`.** Agregar la sección `flutter_native_splash:` con:
   - `color: "#64009D"`
   - `image: resources/art/splash_logo.png`
   - Bloque `android_12:` con `color: "#64009D"` e `image: resources/art/splash_logo.png`.
   *Test manual:* la config es válida.

6. **Generar el splash.** Ejecutar `dart run flutter_native_splash:create`. *Test manual:* se generan los recursos de splash; al abrir la app se ve el logo blanco centrado sobre fondo morado.

7. **Verificación integral.** `flutter analyze` limpio y `flutter test` verde. Correr la app en Android y verificar: (a) ícono en el launcher, (b) ícono adaptativo se ve bien en launcher moderno, (c) splash morado con logo blanco al arrancar, (d) splash correcto en un dispositivo/emulador Android 12+. *Test manual:* instalar y abrir la app desde cero.

---

## Criterios de aceptación

- [ ] Existen las carpetas `ios/`, `web/`, `windows/`, `macos/` y `linux/` además de `android/`, y la carpeta `android/` previa sigue funcionando.
- [ ] `pubspec.yaml` incluye `flutter_launcher_icons` y `flutter_native_splash` en `dev_dependencies`.
- [ ] `pubspec.yaml` tiene la sección `flutter_launcher_icons:` con `image_path: resources/art/icon.png`, `adaptive_icon_foreground: resources/art/icon.png` y `adaptive_icon_background: "#64009D"`.
- [ ] `pubspec.yaml` tiene la sección `flutter_native_splash:` con `color: "#64009D"`, `image: resources/art/splash_logo.png` y un bloque `android_12:` con el mismo color e imagen.
- [ ] Al instalar la app en Android, el launcher muestra el ícono generado desde `icon.png` (ya no el ícono por defecto de Flutter).
- [ ] En un launcher con íconos adaptativos, el ícono se ve con foreground `icon.png` sobre fondo `#64009D`.
- [ ] Al abrir la app, aparece un splash con el logo de `splash_logo.png` centrado sobre fondo `#64009D`.
- [ ] En un dispositivo/emulador Android 12+, el splash nativo respeta el logo y el fondo `#64009D`.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Cómo generar ícono y splash | Paquetes `flutter_launcher_icons` + `flutter_native_splash` por CLI | Colocar los PNG a mano en `mipmap-*` / recursos nativos | Reproducible y regenerable; evita manipular recursos nativos plataforma por plataforma. |
| Plataformas | Crear todas (`ios`, `web`, `windows`, `macos`, `linux`) además de Android | Limitar solo a Android | Pedido del usuario: dejar las carpetas listas para más adelante. |
| Color de fondo del splash | Morado principal `#64009D` | Morado oscuro del fondo / blanco | El logo es un contorno blanco; sobre `#64009D` queda visible y alineado con la paleta (SPEC 03). Sobre blanco sería casi invisible. |
| Tipo de ícono Android | Adaptativo (foreground `icon.png` + fondo `#64009D`) además del legacy | Solo ícono legacy | Se ve correctamente en launchers modernos sin recortes ni bordes raros. |
| Splash Android 12+ | Activar bloque `android_12:` con mismo logo y fondo | Dejar solo el splash clásico | Consistencia visual en dispositivos nuevos que usan la API nativa de splash. |
| Imágenes fuente | Usar `icon.png` y `splash_logo.png` tal cual | Rediseñar/recortar las imágenes | Vienen con las dimensiones correctas; el rediseño queda fuera de alcance. |
| Incompatibilidad `jni` 1.0.1 con AGP 9 | `dependency_overrides: path_provider_android: 2.2.17` | Bajar AGP a 8.x / parchear `jni` en el pub cache | `flutter_native_splash` (dev-only) arrastra `path_provider_android` 2.3.x → `jni` 1.0.1, que usa el bloque `kotlin {}` sin aplicar el plugin de Kotlin cuando AGP >= 9 (`Could not find method kotlin()`). La app no usa `path_provider` en runtime; fijar la última versión previa a `jni` elimina el conflicto sin tocar la config nativa. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| `flutter create` sobre un proyecto existente puede regenerar/tocar archivos de `android/` | Podría pisar configuración manual en `android/` | Usar `--platforms` solo con las plataformas nuevas; revisar el diff de `android/` tras el comando y descartar cambios no deseados. |
| El logo del splash es un contorno blanco; si el paquete lo escala mal podría verse muy chico o pixelado | Splash con logo poco visible | Verificar visualmente en emulador; ajustar tamaño/`fill` en la config de `flutter_native_splash` si hace falta. |
| Compatibilidad de versiones de los paquetes con el SDK `^3.12.2` | `pub get` podría fallar o traer una versión no esperada | Fijar versiones compatibles y validar con `flutter pub get` antes de generar. |
| Los recursos generados quedan versionados y pueden ensuciar el diff | Commit grande con muchos binarios | Revisar que solo se versionen los recursos esperados de ícono/splash. |
| Toolchain con AGP 9 rompe el build por el transitivo `jni` 1.0.1 (vía `path_provider_android` de `flutter_native_splash`) | `assembleDebug` falla con `Could not find method kotlin()` | Resuelto con `dependency_overrides: path_provider_android: 2.2.17` (versión previa a `jni`); revisar si futuras versiones de `flutter_native_splash`/`path_provider_android` ya soportan AGP 9 para retirar el override. |

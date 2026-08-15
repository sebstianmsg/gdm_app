# SPEC 23 — Nombre visible de la app "Gastos del mes"

> **Estado:** Implementado
> **Depende de:** SPEC 05 (ícono de app y generación de plataformas)
> **Fecha:** 2026-08-15
> **Objetivo (una frase):** Cambiar el nombre visible de la app de `gdm_app` a **"Gastos del mes"** en todas las plataformas (Android launcher, web, iOS, Windows, Linux y macOS), tocando solo las etiquetas mostradas al usuario y dejando intactos los identificadores internos (`pubspec name`, nombres de binario/ejecutable y `applicationId`/bundle id).

---

## Alcance

**Dentro** — cambiar solo la etiqueta visible a **"Gastos del mes"** en:

1. **Android (launcher / galería).** `android:label` en `android/app/src/main/AndroidManifest.xml`.
2. **Web.** En `web/index.html`: `<title>` y `<meta name="apple-mobile-web-app-title">`. En `web/manifest.json`: `name` y `short_name`.
3. **iOS.** `CFBundleDisplayName` (nombre bajo el ícono) y `CFBundleName` en `ios/Runner/Info.plist`.
4. **Windows.** Título de ventana en `windows/runner/main.cpp` (`window.Create(L"...")`) y los valores visibles `FileDescription` y `ProductName` en `windows/runner/Runner.rc`.
5. **Linux.** `gtk_header_bar_set_title` y `gtk_window_set_title` en `linux/runner/my_application.cc`.
6. **macOS.** Agregar `CFBundleDisplayName` = "Gastos del mes" en `macos/Runner/Info.plist` (para no renombrar el binario vía `PRODUCT_NAME`).

**Fuera de alcance:**

- `name: gdm_app` en `pubspec.yaml` (identificador del paquete Dart; cambiarlo rompe todos los imports `package:gdm_app/...`).
- Nombres de binario/ejecutable e identificadores: `BINARY_NAME`/`APPLICATION_ID` en `linux/CMakeLists.txt`, `PRODUCT_NAME` en `macos/.../AppInfo.xcconfig`, `InternalName`/`OriginalFilename` (`gdm_app.exe`) en `Runner.rc`, `applicationId` de Android y bundle id de iOS.
- Regenerar íconos/splash (SPEC 05) ni cambiar branding gráfico.
- Forzar el número de líneas o el truncado del texto en el launcher (no es configurable).

---

## Modelo de datos

Este spec **no introduce ni modifica datos**. Solo cambia cadenas de texto de configuración/etiqueta en archivos de plataforma. No hay estructuras, columnas ni persistencia nuevas.

---

## Plan de implementación

Cada paso deja el proyecto compilando.

1. **Android.** En `android/app/src/main/AndroidManifest.xml` cambiar `android:label="gdm_app"` → `android:label="Gastos del mes"`. *Verificación:* al instalar en Android, el ícono aparece con "Gastos del mes".

2. **Web.** En `web/index.html`: `<title>gdm_app</title>` → `<title>Gastos del mes</title>` y `apple-mobile-web-app-title` content `gdm_app` → `Gastos del mes`. En `web/manifest.json`: `name` y `short_name` → `Gastos del mes`. *Verificación:* la pestaña del navegador y el PWA muestran "Gastos del mes".

3. **iOS.** En `ios/Runner/Info.plist`: `CFBundleDisplayName` `Gdm App` → `Gastos del mes` y `CFBundleName` `gdm_app` → `Gastos del mes`. *Verificación:* el nombre bajo el ícono en iOS es "Gastos del mes".

4. **Windows.** En `windows/runner/main.cpp`: `window.Create(L"gdm_app", ...)` → `L"Gastos del mes"`. En `windows/runner/Runner.rc`: `FileDescription` y `ProductName` `gdm_app` → `Gastos del mes` (dejar `InternalName` y `OriginalFilename`/`gdm_app.exe` intactos). *Verificación:* el título de la ventana y las propiedades del `.exe` muestran "Gastos del mes".

5. **Linux.** En `linux/runner/my_application.cc`: `gtk_header_bar_set_title(header_bar, "gdm_app")` y `gtk_window_set_title(window, "gdm_app")` → `"Gastos del mes"` (dejar `BINARY_NAME`/`APPLICATION_ID` del `CMakeLists.txt` intactos). *Verificación:* el título de la ventana en Linux es "Gastos del mes".

6. **macOS.** En `macos/Runner/Info.plist` agregar la clave `CFBundleDisplayName` con valor `Gastos del mes` (sin tocar `PRODUCT_NAME`). *Verificación:* el nombre mostrado de la app en macOS es "Gastos del mes".

7. **Verificación integral.** `flutter analyze` limpio y `flutter test` verde; ninguno de estos cambios afecta código Dart. *Verificación:* build de Android OK y el launcher muestra "Gastos del mes".

---

## Criterios de aceptación

- [ ] `android:label` en `AndroidManifest.xml` vale `Gastos del mes`; al instalar en Android el ícono muestra "Gastos del mes".
- [ ] `web/index.html` tiene `<title>Gastos del mes</title>` y `apple-mobile-web-app-title` = `Gastos del mes`.
- [ ] `web/manifest.json` tiene `name` y `short_name` = `Gastos del mes`.
- [ ] `ios/Runner/Info.plist` tiene `CFBundleDisplayName` y `CFBundleName` = `Gastos del mes`.
- [ ] `windows/runner/main.cpp` crea la ventana con título `Gastos del mes`; `Runner.rc` tiene `FileDescription` y `ProductName` = `Gastos del mes`, y `InternalName`/`OriginalFilename` siguen siendo `gdm_app`/`gdm_app.exe`.
- [ ] `linux/runner/my_application.cc` usa `Gastos del mes` en `gtk_header_bar_set_title` y `gtk_window_set_title`; `BINARY_NAME`/`APPLICATION_ID` siguen siendo `gdm_app`/`com.gdm.gdm_app`.
- [ ] `macos/Runner/Info.plist` tiene `CFBundleDisplayName` = `Gastos del mes`; `PRODUCT_NAME` sigue siendo `gdm_app`.
- [ ] `pubspec.yaml` mantiene `name: gdm_app` (sin cambios) y no hay imports rotos.
- [ ] `flutter analyze` no reporta errores.
- [ ] `flutter test` pasa en verde.

---

## Decisiones tomadas y descartadas

| Decisión | Elegido | Descartado | Justificación |
|---|---|---|---|
| Texto del nombre | **"Gastos del mes"** completo (14 caracteres) | Nombre corto tipo "Gastos" / "Gastos mes" | Pedido explícito del usuario; entra sin problema como nombre de la app. |
| Alcance de plataformas | **Todas** (Android, web, iOS, Windows, Linux, macOS) | Solo Android | Pedido del usuario: dejarlo listo en todas de una vez. |
| `name:` de `pubspec.yaml` | **No tocar** (`gdm_app`) | Renombrar el paquete Dart | Es el identificador interno; cambiarlo rompe todos los imports `package:gdm_app/...`. |
| Nombres de binario/identificador | **Intactos** (`gdm_app.exe`, `BINARY_NAME`, `APPLICATION_ID`, `PRODUCT_NAME`, `applicationId`, bundle id) | Renombrarlos junto con la etiqueta | Solo se pidió el nombre visible; tocar binarios/ids obliga a reconfigurar build, firmas y publicación. |
| macOS | **Agregar `CFBundleDisplayName`** en `Info.plist` | Cambiar `PRODUCT_NAME` en el xcconfig | `PRODUCT_NAME` renombra el ejecutable/bundle; `CFBundleDisplayName` cambia solo el nombre mostrado. |
| Truncado en el launcher | **No controlarlo desde la app** | Forzar 1/2 líneas o abreviar | El truncado lo decide cada launcher de Android; no hay API para forzarlo. |

---

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Un launcher de Android angosto puede truncar "Gastos del mes" a "Gastos del…". | Nombre parcialmente visible en algunos dispositivos. | Es comportamiento del launcher, no un bug; el nombre real sigue siendo correcto. Si molesta, evaluar un nombre corto en un spec futuro. |
| Regenerar plataformas con `flutter create` (o `flutter_native_splash`/`launcher_icons`) podría pisar `main.cpp`, `Info.plist`, `manifest.json`, etc. | Se pierde el nombre en algún archivo generado. | Revisar el diff tras cualquier regeneración de plataformas y reaplicar la etiqueta si hiciera falta. |

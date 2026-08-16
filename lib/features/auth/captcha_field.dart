import 'package:flutter/material.dart';
import 'package:flutter_turnstile/flutter_turnstile.dart';

import '../../config/env.dart';

/// Campo de captcha reutilizable para los flujos de auth por email (spec 22).
///
/// Envuelve `flutter_turnstile` con la `TURNSTILE_SITE_KEY` y expone los
/// callbacks del ciclo de vida del token:
///   - [onToken]: se emitió un token válido (habilita el envío del form).
///   - [onExpired]: el token caducó (~5 min); el form debe volver a `null`.
///   - [onError]: el widget falló (sin red, WebView bloqueada, etc.).
///
/// El [controller] lo provee el form padre para poder **resetear** el widget
/// tras cada envío (el token de Turnstile es de un solo uso): basta con llamar
/// `controller.refreshToken()`.
class CaptchaField extends StatelessWidget {
  const CaptchaField({
    super.key,
    required this.controller,
    required this.onToken,
    this.onExpired,
    this.onError,
  });

  /// Controlador compartido con el form padre. Permite resetear el widget
  /// (`controller.refreshToken()`) para forzar un token nuevo antes de
  /// reintentar.
  final TurnstileController controller;

  /// Se dispara cuando Turnstile emite un token válido.
  final ValueChanged<String> onToken;

  /// Se dispara cuando el token caduca antes de usarse.
  final VoidCallback? onExpired;

  /// Se dispara ante un error del widget (sin red, WebView bloqueada, etc.).
  final ValueChanged<String>? onError;

  /// Solo para tests: reemplaza el WebView de Turnstile por un stub. `flutter
  /// turnstile` monta un WebView que no tiene plataforma en `flutter test`;
  /// este hook permite simular la resolución del captcha sin él. En producción
  /// queda `null` y se renderiza el widget real.
  @visibleForTesting
  static Widget Function(BuildContext context, CaptchaField field)? debugBuilder;

  @override
  Widget build(BuildContext context) {
    final override = debugBuilder;
    if (override != null) return override(context, this);
    // El widget de Turnstile es un iframe fijo de 300px dentro de un WebView
    // del mismo ancho (`flutter_turnstile` lo cablea a `size.width`). En
    // pantallas con densidad de píxeles fraccionaria el borde derecho del
    // iframe (la nube y la "E" de CLOUDFLARE) cae sobre el límite de redondeo
    // y se recorta unos px. Envolverlo en un `SizedBox` un poco más ancho fuerza
    // al WebView a ese ancho (por las constraints ajustadas del SizedBox), de
    // modo que el iframe de 300px queda con margen a la derecha y no se corta.
    return Center(
      child: SizedBox(
        width: 312,
        height: 70,
        child: CloudFlareTurnstile(
          siteKey: Env.turnstileSiteKey,
          controller: controller,
          options: TurnstileOptions(
            theme: Theme.of(context).brightness == Brightness.dark
                ? TurnstileTheme.dark
                : TurnstileTheme.light,
          ),
          onTokenReceived: onToken,
          onTokenExpired: onExpired,
          onError: onError,
        ),
      ),
    );
  }
}

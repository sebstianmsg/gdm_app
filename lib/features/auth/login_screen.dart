import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_turnstile/flutter_turnstile.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_login_background.dart';
import 'auth_provider.dart';
import 'captcha_field.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TurnstileController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  // Token de Turnstile (uso único): null ⇒ botón deshabilitado.
  String? _captchaToken;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final token = _captchaToken;
    if (email.isEmpty || password.isEmpty || token == null) return;
    await ref
        .read(authProvider.notifier)
        .login(email, password, captchaToken: token, rememberMe: _rememberMe);
    // El token es de un solo uso: reseteamos el widget para obtener uno nuevo
    // antes de reintentar (éxito o error).
    _resetCaptcha();
  }

  void _resetCaptcha() {
    _captchaController.refreshToken();
    if (mounted) setState(() => _captchaToken = null);
  }

  void _openSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedLoginBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // El título va sobre el fondo animado oscuro (idéntico en
                  // ambos temas), así que se mantiene claro siempre.
                  Text(
                    'LIBRO DE GASTOS',
                    style: AppTextStyles.eyebrow(context)
                        .copyWith(color: AppPalette.dark.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mis gastos',
                    style: AppTextStyles.h1(context)
                        .copyWith(color: AppPalette.dark.text),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius: BorderRadius.circular(AppRadius.modal),
                      border: Border.all(color: context.palette.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Iniciar sesión',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(hintText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Contraseña',
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: context.palette.textMuted,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: auth.isSubmitting
                                  ? null
                                  : (v) => setState(
                                      () => _rememberMe = v ?? false,
                                    ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: auth.isSubmitting
                                    ? null
                                    : () => setState(
                                        () => _rememberMe = !_rememberMe,
                                      ),
                                child: Text(
                                  'Recordarme',
                                  style: AppTextStyles.muted(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: auth.isSubmitting
                                ? null
                                : _openForgotPassword,
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CaptchaField(
                          controller: _captchaController,
                          onToken: (token) =>
                              setState(() => _captchaToken = token),
                          onExpired: () {
                            setState(() => _captchaToken = null);
                            ref
                                .read(authProvider.notifier)
                                .reportCaptchaExpired();
                          },
                          onError: (_) {
                            setState(() => _captchaToken = null);
                            ref
                                .read(authProvider.notifier)
                                .reportCaptchaError();
                          },
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            auth.error!,
                            style: TextStyle(color: context.palette.alert),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                auth.isSubmitting || _captchaToken == null
                                ? null
                                : _submit,
                            child: auth.isSubmitting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.palette.inkText,
                                    ),
                                  )
                                : const Text('Iniciar sesión'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: auth.isSubmitting
                                ? null
                                : () => ref
                                      .read(authProvider.notifier)
                                      .signInWithGoogle(),
                            icon: const Icon(Icons.login),
                            label: const Text('Continuar con Google'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: auth.isSubmitting ? null : _openSignup,
                            child: const Text('Crear cuenta'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

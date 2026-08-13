import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_turnstile/flutter_turnstile.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_login_background.dart';
import 'auth_provider.dart';
import 'auth_validators.dart';
import 'captcha_field.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _captchaController = TurnstileController();
  bool _obscurePassword = true;
  // Cuando el alta es exitosa, mostramos el aviso de "revisá tu email".
  bool _submitted = false;
  // Token de Turnstile (uso único): null ⇒ botón deshabilitado.
  String? _captchaToken;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final token = _captchaToken;
    if (token == null) return;
    final notifier = ref.read(authProvider.notifier);
    await notifier.signUpWithEmail(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      captchaToken: token,
    );
    if (!mounted) return;
    // El token es de un solo uso: reseteamos el widget tras el envío (éxito o
    // error) para obtener uno nuevo antes de reintentar.
    _resetCaptcha();
    // Solo mostramos el aviso si no quedó un error en el estado.
    if (ref.read(authProvider).error == null) {
      setState(() => _submitted = true);
    }
  }

  void _resetCaptcha() {
    _captchaController.refreshToken();
    if (mounted) setState(() => _captchaToken = null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        // La AppBar flota sobre el fondo animado oscuro (idéntico en ambos
        // temas), así que su texto/íconos se mantienen claros siempre.
        foregroundColor: AppPalette.dark.text,
        title: const Text('Crear cuenta'),
      ),
      extendBodyBehindAppBar: true,
      body: AnimatedLoginBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.modal),
                  border: Border.all(color: context.palette.line),
                ),
                child: _submitted
                    ? _buildConfirmationNotice(context)
                    : _buildForm(context, auth),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationNotice(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.mark_email_read_outlined,
            color: context.palette.ink, size: 40),
        const SizedBox(height: 16),
        Text(
          'Revisá tu email',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Te enviamos un email a ${_emailController.text.trim()} para '
          'confirmar tu cuenta. Tocá el link del email para activarla.',
          style: AppTextStyles.muted(context),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver al login'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, AuthState auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Crear cuenta',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Nombre'),
            validator: AuthValidators.name,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Email'),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
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
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: AuthValidators.password,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(hintText: 'Confirmar contraseña'),
            validator: (v) =>
                AuthValidators.confirmPassword(v, _passwordController.text),
          ),
          const SizedBox(height: 12),
          CaptchaField(
            controller: _captchaController,
            onToken: (token) => setState(() => _captchaToken = token),
            onExpired: () {
              setState(() => _captchaToken = null);
              ref.read(authProvider.notifier).reportCaptchaExpired();
            },
            onError: (_) {
              setState(() => _captchaToken = null);
              ref.read(authProvider.notifier).reportCaptchaError();
            },
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Text(
              auth.error!,
              style: TextStyle(color: context.palette.alert),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: auth.isSubmitting || _captchaToken == null
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
                  : const Text('Crear cuenta'),
            ),
          ),
        ],
      ),
    );
  }
}

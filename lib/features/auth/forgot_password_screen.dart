import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_login_background.dart';
import 'auth_provider.dart';
import 'auth_validators.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .sendPasswordReset(_emailController.text.trim());
    if (!mounted) return;
    if (ref.read(authProvider).error == null) {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Recuperar contraseña'),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.modal),
                  border: Border.all(color: AppColors.line),
                ),
                child: _sent
                    ? _buildSentNotice(context)
                    : _buildForm(context, auth),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentNotice(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            color: AppColors.ink, size: 40),
        const SizedBox(height: 16),
        Text('Te enviamos un email',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Si ${_emailController.text.trim()} tiene una cuenta, te llegará un '
          'link para restablecer tu contraseña. Tocá el link desde este '
          'dispositivo.',
          style: AppTextStyles.muted,
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
          Text('¿Olvidaste tu contraseña?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Ingresá tu email y te enviamos un link para crear una nueva.',
            style: AppTextStyles.muted,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(hintText: 'Email'),
            validator: AuthValidators.email,
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Text(auth.error!, style: const TextStyle(color: AppColors.alert)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: auth.isSubmitting ? null : _submit,
              child: auth.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.inkText,
                      ),
                    )
                  : const Text('Enviar link'),
            ),
          ),
        ],
      ),
    );
  }
}

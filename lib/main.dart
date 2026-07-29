import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/month/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Mantiene el splash nativo visible mientras se inicializa Supabase y se
  // quita explícitamente tras el primer frame (evita que quede colgado en
  // Android 12+, donde el auto-quitado no siempre dispara).
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  Env.assertValid();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  // "Recordarme": el SDK siempre restaura la sesión persistida. Si el usuario
  // no marcó "Recordarme" en su último login por email, cerramos esa sesión
  // acá —antes de runApp— para que al reabrir la app aparezca el login. El
  // login con Google fija remember_me=true, así que nunca se desloguea acá.
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession != null) {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(kRememberMeKey) ?? false;
    if (!rememberMe) {
      await auth.signOut();
    }
  }
  runApp(const ProviderScope(child: GdmApp()));
  FlutterNativeSplash.remove();
}

class GdmApp extends StatelessWidget {
  const GdmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gastos del mes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AuthGate(),
    );
  }
}

/// Igual que `boot()` en `public/js/app.js`: sin token -> login; con token
/// (o mientras se resuelve el storage) -> vista mensual. Un 401 en cualquier
/// request revierte automáticamente el estado a `unauthenticated`.
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  @override
  void initState() {
    super.initState();
    // El deep link de reset (`passwordRecovery`) trae una sesión de recovery
    // pero no debe caer en el home: al recibirlo, abrimos reset_password_screen.
    ref.read(authProvider.notifier).onPasswordRecovery.listen((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    switch (auth.status) {
      case AuthStatus.bootstrapping:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/auth_api.dart';
import '../data/categories_api.dart';
import '../data/expenses_api.dart';
import '../data/token_storage.dart';
import '../features/auth/auth_provider.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// El cliente Dio compartido. Ante un 401 de cualquier request, fuerza el
/// logout (limpia token y vuelve al gate de login), igual que hace
/// `apiGet`/`apiSend` en `public/js/app.js`.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
  client.onUnauthorized = () {
    ref.read(authProvider.notifier).forceLogout();
  };
  return client;
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final categoriesApiProvider = Provider<CategoriesApi>(
  (ref) => CategoriesApi(ref.watch(apiClientProvider)),
);

final expensesApiProvider = Provider<ExpensesApi>(
  (ref) => ExpensesApi(ref.watch(apiClientProvider)),
);

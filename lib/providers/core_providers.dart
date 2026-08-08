import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/categories_data.dart';
import '../data/expenses_data.dart';
import '../data/partnerships_data.dart';
import '../data/shared_expenses_data.dart';

/// El cliente Supabase compartido, ya inicializado en `main()`.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final categoriesDataProvider = Provider<CategoriesDataSource>(
  (ref) => CategoriesData(ref.watch(supabaseClientProvider)),
);

final expensesDataProvider = Provider<ExpensesDataSource>(
  (ref) => ExpensesData(ref.watch(supabaseClientProvider)),
);

final partnershipsDataProvider = Provider<PartnershipsDataSource>(
  (ref) => PartnershipsData(ref.watch(supabaseClientProvider)),
);

final sharedExpensesDataProvider = Provider<SharedExpensesDataSource>(
  (ref) => SharedExpensesData(ref.watch(supabaseClientProvider)),
);

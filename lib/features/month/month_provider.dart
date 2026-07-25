import 'package:flutter_riverpod/flutter_riverpod.dart';

DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// Mes actualmente visible en la vista mensual. Arranca en el mes de hoy,
/// como `currentDate` en `public/js/app.js`. Sin límites de navegación.
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => _firstOfMonth(DateTime.now());

  void previous() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  void next() {
    state = DateTime(state.year, state.month + 1, 1);
  }
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(
  SelectedMonthNotifier.new,
);

// Tests de la función pura `summarize` (balance compartido informativo, spec 14).

import 'package:flutter_test/flutter_test.dart';

import 'package:gdm_app/features/shared/shared_balance.dart';
import 'package:gdm_app/models/shared_expense.dart';

SharedExpense _se(double amount, String paidBy) => SharedExpense(
  id: 's-$amount-$paidBy',
  partnershipId: 'p-1',
  description: 'x',
  amount: amount,
  date: DateTime(2026, 8, 1),
  paidBy: paidBy,
  createdBy: paidBy,
);

const me = 'me';
const other = 'other';

void main() {
  group('summarize', () {
    test('mes sin gastos: todo en cero', () {
      final b = summarize([], me: me, partnerName: 'Zoe');
      expect(b.total, 0);
      expect(b.paidByMe, 0);
      expect(b.paidByPartner, 0);
      expect(b.difference, 0);
      expect(b.partnerName, 'Zoe');
    });

    test('todo lo paga uno (yo)', () {
      final b = summarize(
        [_se(100, me), _se(50, me)],
        me: me,
        partnerName: 'Zoe',
      );
      expect(b.total, 150);
      expect(b.paidByMe, 150);
      expect(b.paidByPartner, 0);
      expect(b.difference, 150);
    });

    test('todo lo paga el otro', () {
      final b = summarize(
        [_se(80, other), _se(20, other)],
        me: me,
        partnerName: 'Zoe',
      );
      expect(b.total, 100);
      expect(b.paidByMe, 0);
      expect(b.paidByPartner, 100);
      expect(b.difference, 100);
    });

    test('mezcla: total, aportes y diferencia', () {
      final b = summarize(
        [_se(100, me), _se(40, other), _se(10, other)],
        me: me,
        partnerName: 'Zoe',
      );
      expect(b.total, 150);
      expect(b.paidByMe, 100);
      expect(b.paidByPartner, 50);
      expect(b.difference, 50);
    });

    test('difference es el valor absoluto (paga más el otro)', () {
      final b = summarize(
        [_se(20, me), _se(100, other)],
        me: me,
        partnerName: 'Zoe',
      );
      expect(b.difference, 80);
    });
  });
}

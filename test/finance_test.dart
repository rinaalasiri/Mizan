import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/database/finance_database.dart';
import 'package:mizan/providers/finance_state.dart';
import 'package:mizan/repositories/finance_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late FinanceRepository repo;
  late FinanceState state;
  setUp(() async {
    db = await FinanceDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = FinanceRepository(db);
    state = FinanceState(repo);
  });
  tearDown(() async {
    state.dispose();
    await db.close();
  });

  test(
    'creates, edits, filters and removes transactions in integer halalas',
    () async {
      await repo.save('transactions', {
        'id': 100,
        'category_id': 9,
        'type': 'income',
        'amount': 100001,
        'date': '2026-03-01',
      });
      await repo.save('transactions', {
        'id': 101,
        'category_id': 1,
        'type': 'expense',
        'amount': 1001,
        'date': '2026-03-02',
      });
      await repo.save('transactions', {
        'id': 102,
        'category_id': 1,
        'type': 'expense',
        'amount': 25,
        'date': '2026-04-01',
      });
      await state.refresh();
      expect(state.total(state.inMonth('2026-03'), 'expense'), 1001);
      expect(
        state.total(state.transactions, 'income') -
            state.total(state.transactions, 'expense'),
        98975,
      );
      await repo.save('transactions', {'amount': 2000}, 101);
      await repo.remove('transactions', 102);
      await state.refresh();
      expect(state.total(state.inMonth('2026-03'), 'expense'), 2000);
      expect(state.inMonth('2026-04'), isEmpty);
      await expectLater(
        repo.remove('categories', 1),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'monthly recurrence clamps February, returns to anchor and is idempotent',
    () async {
      await repo.save('recurring_transactions', {
        'category_id': 3,
        'type': 'expense',
        'amount': 12345,
        'start_date': '2026-01-31',
        'next_due_date': '2026-01-31',
      });
      await repo.generateDue(DateTime(2026, 3, 31));
      await repo.generateDue(DateTime(2026, 3, 31));
      expect(
        (await repo.rows(
          'transactions',
          order: 'date',
        )).map((row) => row['date']),
        ['2026-01-31', '2026-02-28', '2026-03-31'],
      );
      expect(
        (await repo.rows('recurring_transactions')).single['next_due_date'],
        '2026-04-30',
      );
    },
  );

  test('demo reset keeps user transactions and budgets', () async {
    await repo.save('transactions', {
      'category_id': 1,
      'type': 'expense',
      'amount': 500,
      'date': '2026-03-02',
    });
    await repo.save('budgets', {'month': '2026-03', 'limit_amount': 15000});
    await repo.demo(true, DateTime(2026, 3, 4));
    await repo.demo(true, DateTime(2026, 3, 4));
    expect((await repo.rows('transactions')).length, 37);
    await repo.demo(false, DateTime(2026, 3, 4));
    expect((await repo.rows('transactions')).single['amount'], 500);
    expect((await repo.rows('budgets')).single['limit_amount'], 15000);
    expect(await repo.rows('recurring_transactions'), isEmpty);
  });
}

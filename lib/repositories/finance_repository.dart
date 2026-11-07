import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../database/finance_database.dart';

class FinanceRepository {
  FinanceRepository(this.db);
  final Database db;

  Future<List<RowData>> rows(String table, {String? order}) =>
      db.query(table, orderBy: order);

  Future<void> save(String table, RowData values, [int? id]) async {
    if (id == null) {
      await db.insert(table, values);
    } else {
      await db.update(table, values, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> remove(String table, int id) async {
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> generateDue(DateTime today) => db.transaction((txn) async {
    final rules = await txn.query(
      'recurring_transactions',
      where: 'is_active=1 AND next_due_date <= ?',
      whereArgs: [day(today)],
    );
    for (final rule in rules) {
      var due = DateTime.parse(rule['next_due_date'] as String);
      final anchor = DateTime.parse(rule['start_date'] as String).day;
      while (day(due).compareTo(day(today)) <= 0) {
        await txn.insert('transactions', {
          for (final key in ['amount', 'category_id', 'type', 'note', 'demo'])
            key: rule[key],
          'recurring_id': rule['id'],
          'date': day(due),
          'occurrence': day(due),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        final next = DateTime(due.year, due.month + 1);
        due = DateTime(
          next.year,
          next.month,
          min(anchor, DateTime(next.year, next.month + 1, 0).day),
        );
      }
      await txn.update(
        'recurring_transactions',
        {'next_due_date': day(due)},
        where: 'id=?',
        whereArgs: [rule['id']],
      );
    }
  });

  Future<void> demo(bool load, DateTime today) => db.transaction((txn) async {
    for (final table in ['transactions', 'recurring_transactions', 'budgets']) {
      await txn.delete(table, where: 'demo=1');
    }
    if (!load) return;
    for (var offset = 0; offset < 6; offset++) {
      for (final (category, amount, date, note) in [
        (9, 980000, 1, 'Payroll'),
        (1, 46000, 2, 'Groceries'),
        (2, 17500, 3, 'Fuel'),
        (4, 26500, 4, 'Home supplies'),
        (3, 34000, 5, 'Utilities'),
        (5, 12000, 6, 'Cinema'),
      ]) {
        await txn.insert('transactions', {
          'category_id': category,
          'amount': amount - (category == 9 ? 0 : offset * 1300),
          'date': day(
            DateTime(today.year, today.month - offset, min(today.day, date)),
          ),
          'note': note,
          'type': category == 9 ? 'income' : 'expense',
          'demo': 1,
        });
      }
    }
    for (final (category, limit) in [(null, 240000), (1, 55000), (2, 40000)]) {
      await txn.insert('budgets', {
        'category_id': category,
        'month': month(today),
        'limit_amount': limit,
        'demo': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final start = day(DateTime(today.year, today.month + 1, 1));
    await txn.insert('recurring_transactions', {
      'category_id': 3,
      'amount': 12900,
      'type': 'expense',
      'note': 'Internet',
      'start_date': start,
      'next_due_date': start,
      'demo': 1,
    });
  });
}

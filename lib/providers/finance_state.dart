import 'package:flutter/foundation.dart';
import '../database/finance_database.dart';
import '../repositories/finance_repository.dart';

class FinanceState extends ChangeNotifier {
  FinanceState(this.repository);
  final FinanceRepository repository;
  List<RowData> categories = [], transactions = [], budgets = [], rules = [];
  RowData settings = {};
  bool get ar => settings['language'] != 'en';
  bool get dark => settings['theme_mode'] == 'dark';

  Future<void> refresh() async {
    categories = await repository.rows('categories', order: 'id');
    transactions = await repository.rows(
      'transactions',
      order: 'date DESC,id DESC',
    );
    budgets = await repository.rows('budgets');
    rules = await repository.rows(
      'recurring_transactions',
      order: 'next_due_date',
    );
    settings = (await repository.rows('app_settings')).single;
    notifyListeners();
  }

  Future<void> change(Future<void> Function(FinanceRepository) action) async {
    await action(repository);
    await repository.generateDue(DateTime.now());
    await refresh();
  }

  List<RowData> inMonth(String month) => transactions
      .where((row) => (row['date'] as String).startsWith(month))
      .toList();

  int total(Iterable<RowData> rows, String type) => rows
      .where((row) => row['type'] == type)
      .fold(0, (sum, row) => sum + (row['amount'] as int));

  RowData category(int id) => categories.firstWhere((row) => row['id'] == id);
  String name(int id) {
    final row = category(id);
    return (ar ? row['arabic'] ?? row['name'] : row['name']) as String;
  }
}

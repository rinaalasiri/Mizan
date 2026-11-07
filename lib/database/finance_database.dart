import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

String day(DateTime date) => date.toIso8601String().substring(0, 10);
String month(DateTime date) => day(date).substring(0, 7);
typedef RowData = Map<String, Object?>;

class FinanceDatabase {
  static Future<Database> open({
    DatabaseFactory? factory,
    String path = 'mizan.db',
  }) => (factory ?? databaseFactoryFfiWeb).openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final batch = db.batch();
        for (final sql in [
          '''CREATE TABLE categories (
            id INTEGER PRIMARY KEY, name TEXT NOT NULL, arabic TEXT,
            type TEXT NOT NULL CHECK(type IN ('income','expense')),
            icon INTEGER NOT NULL, color INTEGER NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0)''',
          '''CREATE TABLE recurring_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT, amount INTEGER NOT NULL CHECK(amount>0),
            category_id INTEGER NOT NULL REFERENCES categories(id),
            type TEXT NOT NULL, note TEXT, frequency TEXT NOT NULL DEFAULT 'monthly',
            start_date TEXT NOT NULL, next_due_date TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1, demo INTEGER NOT NULL DEFAULT 0)''',
          '''CREATE TABLE transactions (
            id INTEGER PRIMARY KEY, amount INTEGER NOT NULL CHECK(amount>0),
            category_id INTEGER NOT NULL REFERENCES categories(id),
            type TEXT NOT NULL, date TEXT NOT NULL, note TEXT,
            recurring_id INTEGER REFERENCES recurring_transactions(id) ON DELETE SET NULL,
            occurrence TEXT, demo INTEGER NOT NULL DEFAULT 0, UNIQUE(recurring_id, occurrence))''',
          '''CREATE TABLE budgets (
            id INTEGER PRIMARY KEY, category_id INTEGER REFERENCES categories(id),
            month TEXT NOT NULL, limit_amount INTEGER NOT NULL CHECK(limit_amount>0),
            demo INTEGER NOT NULL DEFAULT 0)''',
          'CREATE UNIQUE INDEX budget_scope ON budgets(month, COALESCE(category_id,0))',
          'CREATE INDEX transaction_date ON transactions(date)',
          'CREATE INDEX transaction_category ON transactions(category_id)',
          'CREATE INDEX recurrence_due ON recurring_transactions(is_active,next_due_date)',
          "CREATE TABLE app_settings (id INTEGER PRIMARY KEY CHECK(id=1), language TEXT, theme_mode TEXT, currency TEXT DEFAULT 'SAR')",
          "INSERT INTO app_settings(id,language,theme_mode) VALUES(1,'en','dark')",
        ]) {
          batch.execute(sql);
        }
        const labels = [
          ('Food', 'طعام'),
          ('Transport', 'مواصلات'),
          ('Bills', 'فواتير'),
          ('Shopping', 'تسوق'),
          ('Entertainment', 'ترفيه'),
          ('Healthcare', 'صحة'),
          ('Education', 'تعليم'),
          ('Other', 'أخرى'),
          ('Salary', 'راتب'),
          ('Freelance', 'عمل حر'),
          ('Allowance', 'مصروف'),
          ('Other', 'أخرى'),
        ];
        for (var i = 0; i < labels.length; i++) {
          batch.insert('categories', {
            'id': i + 1,
            'name': labels[i].$1,
            'arabic': labels[i].$2,
            'type': i < 8 ? 'expense' : 'income',
            'icon': i,
            'color': i % 6,
            'is_default': 1,
          });
        }
        await batch.commit(noResult: true);
      },
    ),
  );
}

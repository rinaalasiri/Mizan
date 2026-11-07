import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../database/finance_database.dart';
import '../providers/finance_state.dart';
import '../repositories/finance_repository.dart';

part 'finance_views.dart';
part 'finance_editors.dart';

const palette = [
  Color(0xff16775b),
  Color(0xff397ba9),
  Color(0xffb26b25),
  Color(0xff8766ad),
  Color(0xffc35768),
  Color(0xff508a75),
];
const icons = [
  Icons.restaurant_rounded,
  Icons.directions_car_rounded,
  Icons.receipt_long_rounded,
  Icons.shopping_bag_rounded,
  Icons.movie_rounded,
  Icons.favorite_rounded,
  Icons.school_rounded,
  Icons.category_rounded,
  Icons.payments_rounded,
  Icons.work_rounded,
  Icons.wallet_rounded,
  Icons.savings_rounded,
];

class FinanceShell extends StatefulWidget {
  const FinanceShell({super.key});
  @override
  State<FinanceShell> createState() => _FinanceShellState();
}

class _FinanceShellState extends State<FinanceShell> {
  void update(VoidCallback change) => setState(change);
  int tab = 0;
  DateTime selected = DateTime.now();
  String search = '', type = '', sort = 'recent';
  int? category;
  bool allMonths = false, busy = false;
  FinanceState get state => context.read<FinanceState>();
  String tr(String ar, String en) => state.ar ? ar : en;
  String get period => month(selected);
  List<RowData> get rows => state.inMonth(period);
  String money(int amount) => NumberFormat.currency(
    locale: state.ar ? 'ar_SA' : 'en',
    symbol: tr('ر.س.', 'SAR'),
    decimalDigits: 2,
  ).format(amount / 100);
  String get periodLabel =>
      DateFormat.yMMMM(state.ar ? 'ar' : 'en').format(selected);
  String kind(Object? value) =>
      value == 'income' ? tr('دخل', 'Income') : tr('مصروف', 'Expense');
  Color categoryColor(RowData row) => palette[row['color'] as int];
  IconData categoryIcon(RowData row) => icons[row['icon'] as int];

  Future<void> mutate(Future<void> Function(FinanceRepository) action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await state.change(action);
    } catch (_) {
      if (mounted) {
        notify(
          tr(
            'تعذّر حفظ التغيير. قد يكون التصنيف مرتبطًا ببيانات أخرى.',
            'Could not save. The category may be linked to other records.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void notify(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void moveMonth(int offset) => setState(() {
    selected = DateTime(selected.year, selected.month + offset);
    allMonths = false;
  });

  Widget monthPicker() => Card(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: tr('الشهر السابق', 'Previous month'),
          onPressed: () => moveMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        TextButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selected,
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (date != null && mounted) {
              setState(() {
                selected = date;
                allMonths = false;
              });
            }
          },
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text(periodLabel),
        ),
        IconButton(
          tooltip: tr('الشهر التالي', 'Next month'),
          onPressed: () => moveMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  Widget panel(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget title(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
  );
  Widget empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 25),
    child: Center(child: Text(text, textAlign: TextAlign.center)),
  );

  @override
  Widget build(BuildContext context) {
    context.watch<FinanceState>();
    final names = [
      tr('الرئيسية', 'Overview'),
      tr('المعاملات', 'Transactions'),
      tr('الإحصاءات', 'Analytics'),
      tr('الميزانية', 'Budgets'),
      tr('الإعدادات', 'Settings'),
    ];
    const navIcons = [
      Icons.space_dashboard_outlined,
      Icons.swap_vert_rounded,
      Icons.bar_chart_rounded,
      Icons.account_balance_wallet_outlined,
      Icons.settings_outlined,
    ];
    final wide = MediaQuery.sizeOf(context).width >= 930;
    final add = FilledButton.icon(
      onPressed: busy ? null : () => editTransaction(),
      icon: const Icon(Icons.add),
      label: Text(tr('إضافة معاملة', 'Add transaction')),
    );
    final logo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: HtmlElementView.fromTagName(
              tagName: 'img',
              onElementCreated: (element) {
                (element as web.HTMLImageElement)
                  ..src = 'app_logo.svg'
                  ..alt = 'Mizan';
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          tr('ميزان', 'Mizan'),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 23),
        ),
      ],
    );
    return Scaffold(
      appBar: wide ? null : AppBar(title: logo),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (value) => setState(() => tab = value),
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: List.generate(
                5,
                (i) => NavigationDestination(
                  icon: Icon(navIcons[i]),
                  label: names[i],
                ),
              ),
            ),
      floatingActionButton: wide ? null : add,
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 220,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 12,
                        ),
                        child: logo,
                      ),
                      for (var i = 0; i < names.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            selected: tab == i,
                            selectedTileColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            leading: Icon(navIcons[i]),
                            title: Text(names[i]),
                            onTap: () => setState(() => tab = i),
                          ),
                        ),
                      const Spacer(),
                      ListTile(
                        leading: const Icon(Icons.lock_outline, size: 18),
                        title: Text(
                          tr('البيانات على جهازك', 'Stored on this device'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                if (busy) const LinearProgressIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(tab),
                    padding: EdgeInsets.fromLTRB(
                      wide ? 36 : 16,
                      wide ? 34 : 12,
                      wide ? 36 : 16,
                      95,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr(
                                        'إدارة الأموال الشخصية',
                                        'PERSONAL FINANCE',
                                      ),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      names[tab],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 33,
                                      ),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (tab != 4) monthPicker(),
                                    if (wide) add,
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            switch (tab) {
                              0 => dashboard(),
                              1 => history(),
                              2 => analytics(),
                              3 => budgetsView(),
                              _ => settingsView(),
                            },
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

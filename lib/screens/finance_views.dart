part of 'finance_shell.dart';

extension _FinanceViews on _FinanceShellState {
  Widget metric(String label, int amount, IconData icon, Color color) => panel(
    Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .13),
          foregroundColor: color,
          child: Icon(icon, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 4),
              Text(
                money(amount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget grid(List<Widget> items, {double minWidth = 240}) => LayoutBuilder(
    builder: (context, constraints) {
      final count = min(
        items.length,
        max(1, ((constraints.maxWidth + 12) / (minWidth + 12)).floor()),
      );
      final width = (constraints.maxWidth - (count - 1) * 12) / count;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map((item) => SizedBox(width: width, child: item))
            .toList(),
      );
    },
  );

  Widget transactionTile(RowData row) {
    final id = row['category_id'] as int;
    final cat = state.category(id);
    final income = row['type'] == 'income';
    final note = (row['note'] ?? '') as String;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: CircleAvatar(
        backgroundColor: categoryColor(cat).withValues(alpha: .13),
        foregroundColor: categoryColor(cat),
        child: Icon(categoryIcon(cat), size: 20),
      ),
      title: Text(
        note.isEmpty ? state.name(id) : note,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${state.name(id)} · ${DateFormat.yMMMd(state.ar ? 'ar' : 'en').format(DateTime.parse(row['date'] as String))}'
        '${row['demo'] == 1 ? tr(' · تجريبي', ' · Demo') : ''}',
      ),
      trailing: Text(
        '${income ? '+' : '−'} ${money(row['amount'] as int)}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: income ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      onTap: busy ? null : () => editTransaction(row),
    );
  }

  Widget dashboard() {
    final income = state.total(rows, 'income');
    final expense = state.total(rows, 'expense');
    final overall = state.budgets
        .where((row) => row['month'] == period && row['category_id'] == null)
        .firstOrNull;
    final balance =
        state.total(state.transactions, 'income') -
        state.total(state.transactions, 'expense');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: const LinearGradient(
              colors: [Color(0xff103b32), Color(0xff19745a)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('الرصيد المتاح', 'AVAILABLE BALANCE'),
                style: const TextStyle(
                  color: Color(0xffc0e9db),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                money(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 39,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  'صافي جميع المعاملات المسجّلة',
                  'Net balance across all recorded transactions',
                ),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        grid([
          metric(
            tr('الدخل الشهري', 'Monthly income'),
            income,
            Icons.south_west,
            palette[0],
          ),
          metric(
            tr('المصروف الشهري', 'Monthly spending'),
            expense,
            Icons.north_east,
            palette[2],
          ),
          if (overall != null)
            metric(
              tr('المتبقي من الميزانية', 'Budget remaining'),
              (overall['limit_amount'] as int) - expense,
              Icons.wallet_outlined,
              palette[1],
            )
          else
            panel(
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wallet_outlined),
                title: Text(tr('اضبط ميزانيتك', 'Set your budget')),
                onTap: () => selectTab(3),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        grid([
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title(tr('المعاملات الأخيرة', 'Recent transactions')),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  empty(
                    tr(
                      'لا توجد معاملات في هذا الشهر.',
                      'No transactions this month.',
                    ),
                  ),
                ...rows.take(5).map(transactionTile),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => selectTab(1),
                    child: Text(tr('عرض المعاملات', 'View transactions')),
                  ),
                ),
              ],
            ),
          ),
          distribution(),
        ], minWidth: 345),
      ],
    );
  }

  void selectTab(int value) => update(() => tab = value);

  Widget history() {
    final list = (allMonths ? state.transactions : rows).where((row) {
      final id = row['category_id'] as int;
      final term = search.trim().toLowerCase();
      return (type.isEmpty || row['type'] == type) &&
          (category == null || category == id) &&
          (state.name(id).toLowerCase().contains(term) ||
              (row['note'] as String? ?? '').toLowerCase().contains(term));
    }).toList();
    if (sort == 'amount') {
      list.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));
    }
    if (sort == 'old') {
      final reversed = list.reversed.toList();
      list
        ..clear()
        ..addAll(reversed);
    }
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: TextFormField(
                  initialValue: search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: tr('ابحث عن معاملة', 'Search transactions'),
                  ),
                  onChanged: (value) => update(() => search = value),
                ),
              ),
              DropdownButton<String>(
                value: type,
                onChanged: (v) => update(() => type = v!),
                items: ['', 'income', 'expense']
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v.isEmpty ? tr('كل الأنواع', 'All types') : kind(v),
                        ),
                      ),
                    )
                    .toList(),
              ),
              DropdownButton<int>(
                value: state.categories.any((row) => row['id'] == category)
                    ? category
                    : null,
                onChanged: (v) => update(() => category = v),
                items: [
                  DropdownMenuItem(
                    child: Text(tr('كل التصنيفات', 'All categories')),
                  ),
                  for (final cat in state.categories)
                    DropdownMenuItem(
                      value: cat['id'] as int,
                      child: Text(
                        '${state.name(cat['id'] as int)} · ${kind(cat['type'])}',
                      ),
                    ),
                ],
              ),
              DropdownButton<String>(
                value: sort,
                onChanged: (v) => update(() => sort = v!),
                items: [
                  DropdownMenuItem(
                    value: 'recent',
                    child: Text(tr('الأحدث أولاً', 'Newest first')),
                  ),
                  DropdownMenuItem(
                    value: 'old',
                    child: Text(tr('الأقدم أولاً', 'Oldest first')),
                  ),
                  DropdownMenuItem(
                    value: 'amount',
                    child: Text(tr('المبلغ الأعلى', 'Highest amount')),
                  ),
                ],
              ),
              FilterChip(
                label: Text(tr('كل الشهور', 'All months')),
                selected: allMonths,
                onSelected: (value) => update(() => allMonths = value),
              ),
            ],
          ),
          const Divider(height: 30),
          if (list.isEmpty)
            empty(
              tr('لا توجد معاملات تطابق البحث.', 'No matching transactions.'),
            ),
          ...list.map(transactionTile),
        ],
      ),
    );
  }

  Map<int, int> breakdown(List<RowData> items) {
    final result = <int, int>{};
    for (final row in items.where((row) => row['type'] == 'expense')) {
      result.update(
        row['category_id'] as int,
        (value) => value + (row['amount'] as int),
        ifAbsent: () => row['amount'] as int,
      );
    }
    return result;
  }

  Widget distribution() {
    final entries = breakdown(rows).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title(tr('توزيع المصروفات', 'Spending breakdown')),
          if (entries.isEmpty)
            empty(
              tr(
                'أضف مصروفًا لعرض التوزيع.',
                'Add an expense to see the breakdown.',
              ),
            )
          else ...[
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 50,
                  sectionsSpace: 3,
                  sections: entries
                      .map(
                        (entry) => PieChartSectionData(
                          value: entry.value.toDouble(),
                          radius: 24,
                          showTitle: false,
                          color: categoryColor(state.category(entry.key)),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: categoryColor(state.category(entry.key)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.name(entry.key))),
                    Text(money(entry.value)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget analytics() {
    final dates = List.generate(
      6,
      (i) => DateTime(selected.year, selected.month - 5 + i),
    );
    final values = dates
        .map((date) => state.total(state.inMonth(month(date)), 'expense'))
        .toList();
    final counts = <int, int>{};
    for (final row in rows.where((row) => row['type'] == 'expense')) {
      counts.update(row['category_id'] as int, (v) => v + 1, ifAbsent: () => 1);
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        grid([
          metric(
            tr('إجمالي المصروفات', 'Total spending'),
            values.last,
            Icons.payments_outlined,
            palette[0],
          ),
          metric(
            tr('الفرق عن الشهر السابق', 'Change vs. previous month'),
            values.last - values[4],
            Icons.compare_arrows,
            palette[1],
          ),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('الأكثر استخدامًا', 'Most frequent category')),
                title(ranked.isEmpty ? '—' : state.name(ranked.first.key)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 15),
        grid([
          distribution(),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title(tr('المصروفات خلال ستة أشهر', 'Six-month spending')),
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  child: BarChart(
                    BarChartData(
                      maxY: max(1, values.reduce(max) / 100 * 1.15),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 29,
                            getTitlesWidget: (value, _) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat.MMM(
                                  state.ar ? 'ar' : 'en',
                                ).format(dates[value.toInt()]),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ),
                      barGroups: List.generate(
                        6,
                        (i) => BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: values[i] / 100,
                              width: 19,
                              color: i == 5 ? palette[0] : palette[5],
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ], minWidth: 340),
        const SizedBox(height: 15),
        panel(
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: exportCsv,
                icon: const Icon(Icons.download),
                label: Text(tr('تنزيل CSV', 'Download CSV')),
              ),
              OutlinedButton.icon(
                onPressed: exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(tr('تنزيل PDF', 'Download PDF')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget budgetsView() {
    final budgets = state.budgets.where((row) => row['month'] == period);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: busy ? null : () => editBudget(),
            icon: const Icon(Icons.add),
            label: Text(tr('تعيين حد إنفاق', 'Set spending limit')),
          ),
        ),
        const SizedBox(height: 16),
        if (budgets.isEmpty)
          panel(
            empty(
              tr(
                'لم تُضبط ميزانية لهذا الشهر.',
                'No budgets set for this month.',
              ),
            ),
          ),
        for (final budget in budgets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: budgetCard(budget),
          ),
      ],
    );
  }

  Widget budgetCard(RowData budget) {
    final id = budget['category_id'] as int?;
    final limit = budget['limit_amount'] as int;
    final spent = state.total(
      rows.where((row) => id == null || row['category_id'] == id),
      'expense',
    );
    final progress = spent / limit;
    final color = progress > 1
        ? Theme.of(context).colorScheme.error
        : progress >= .8
        ? palette[2]
        : palette[0];
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: title(
                  id == null
                      ? tr('الميزانية الإجمالية', 'Overall budget')
                      : state.name(id),
                ),
              ),
              if (budget['demo'] == 1) Chip(label: Text(tr('تجريبي', 'Demo'))),
              IconButton(
                onPressed: busy ? null : () => editBudget(budget),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: busy ? null : () => confirmRemove('budgets', budget),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Text('${money(spent)} / ${money(limit)}'),
          const SizedBox(height: 11),
          LinearProgressIndicator(
            value: progress.clamp(0, 1).toDouble(),
            color: color,
            minHeight: 9,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 9),
          Text(
            '${tr('المتبقي', 'Remaining')} · ${money(limit - spent)}',
            style: TextStyle(color: color),
          ),
          if (progress >= .8)
            Text(
              progress > 1
                  ? tr('تجاوزت حد الإنفاق', 'Spending limit exceeded')
                  : tr(
                      'بلغ الإنفاق ٨٠٪ أو أكثر من الحد',
                      'Spending reached at least 80% of the limit',
                    ),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget settingsView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title(tr('التفضيلات', 'Preferences')),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(tr('اللغة', 'Language')),
              trailing: DropdownButton<String>(
                value: state.ar ? 'ar' : 'en',
                onChanged: busy
                    ? null
                    : (v) => mutate(
                        (repo) => repo.save('app_settings', {'language': v}, 1),
                      ),
                items: const [
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: Text(tr('المظهر الداكن', 'Dark mode')),
              value: state.dark,
              onChanged: busy
                  ? null
                  : (v) => mutate(
                      (repo) => repo.save('app_settings', {
                        'theme_mode': v ? 'dark' : 'light',
                      }, 1),
                    ),
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(tr('العملة', 'Currency')),
              trailing: Text(tr('الريال السعودي', 'Saudi riyal')),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: title(tr('التصنيفات', 'Categories'))),
                TextButton.icon(
                  onPressed: busy ? null : () => editCategory(),
                  icon: const Icon(Icons.add),
                  label: Text(tr('إضافة', 'Add')),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: [
                for (final cat in state.categories)
                  InputChip(
                    avatar: Icon(
                      categoryIcon(cat),
                      size: 16,
                      color: categoryColor(cat),
                    ),
                    label: Text(
                      '${state.name(cat['id'] as int)} · ${kind(cat['type'])}',
                    ),
                    onPressed: cat['is_default'] == 1 || busy
                        ? null
                        : () => editCategory(cat),
                    onDeleted: cat['is_default'] == 1 || busy
                        ? null
                        : () => confirmRemove('categories', cat),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: title(
                    tr('المعاملات المتكررة', 'Recurring transactions'),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => editTransaction(null, true),
                  icon: const Icon(Icons.add),
                  label: Text(tr('إضافة', 'Add')),
                ),
              ],
            ),
            if (state.rules.isEmpty)
              empty(
                tr('لم تُضف معاملات متكررة.', 'No recurring transactions yet.'),
              ),
            for (final rule in state.rules)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat),
                title: Text(
                  '${state.name(rule['category_id'] as int)} · ${money(rule['amount'] as int)}'
                  '${rule['demo'] == 1 ? tr(' · تجريبي', ' · Demo') : ''}',
                ),
                subtitle: Text(
                  rule['is_active'] == 1
                      ? '${tr('الاستحقاق التالي', 'Next due')} · ${rule['next_due_date']}'
                      : tr('متوقفة', 'Paused'),
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: tr('تشغيل أو إيقاف', 'Toggle recurrence'),
                      icon: Icon(
                        rule['is_active'] == 1 ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: busy
                          ? null
                          : () => mutate(
                              (repo) => repo.save('recurring_transactions', {
                                'is_active': rule['is_active'] == 1 ? 0 : 1,
                              }, rule['id'] as int),
                            ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy
                          ? null
                          : () => confirmRemove('recurring_transactions', rule),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title(tr('البيانات التجريبية', 'Demo data')),
            const SizedBox(height: 6),
            Text(
              tr(
                'استعرض ميزان باستخدام معاملات وميزانيات تجريبية موسومة.',
                'Explore Mizan with labeled sample transactions and budgets.',
              ),
            ),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => mutate((repo) => repo.demo(true, DateTime.now())),
                  child: Text(tr('تحميل البيانات التجريبية', 'Load demo data')),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () =>
                            mutate((repo) => repo.demo(false, DateTime.now())),
                  child: Text(tr('مسح البيانات التجريبية', 'Clear demo data')),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

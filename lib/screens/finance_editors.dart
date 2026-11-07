part of 'finance_shell.dart';

extension _FinanceEditors on _FinanceShellState {
  String get cancel => tr('إلغاء', 'Cancel');
  String get save => tr('حفظ', 'Save');

  int? parseAmount(String input) {
    var value = input.trim().replaceAll('٫', '.').replaceAll(',', '.');
    const digits = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < digits.length; i++) {
      value = value.replaceAll(digits[i], '${i % 10}');
    }
    if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final amount =
        int.parse(parts.first) * 100 +
        (parts.length == 2 ? int.parse(parts.last.padRight(2, '0')) : 0);
    return amount > 0 ? amount : null;
  }

  Widget amountField(String? initial, ValueChanged<String?> store) =>
      TextFormField(
        initialValue: initial,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: tr('المبلغ بالريال', 'Amount in SAR'),
          prefixIcon: const Icon(Icons.payments_outlined),
        ),
        validator: (value) => parseAmount(value ?? '') == null
            ? tr(
                'أدخل مبلغًا موجبًا بمنزلتين عشريتين كحد أقصى',
                'Enter a positive amount with up to two decimals',
              )
            : null,
        onSaved: store,
      );

  Future<RowData?> formDialog(
    String heading,
    Widget Function(BuildContext, StateSetter) fields,
    RowData Function() result, {
    VoidCallback? delete,
  }) async {
    final form = GlobalKey<FormState>();
    return showDialog<RowData>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: Text(heading),
          content: SizedBox(
            width: 395,
            child: SingleChildScrollView(
              child: Form(key: form, child: fields(context, change)),
            ),
          ),
          actions: [
            if (delete != null)
              IconButton(
                tooltip: tr('حذف', 'Delete'),
                onPressed: () {
                  Navigator.pop(dialog);
                  delete();
                },
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(cancel),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                form.currentState!.save();
                Navigator.pop(dialog, result());
              },
              child: Text(save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> confirmRemove(String table, RowData row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tr('تأكيد الحذف', 'Confirm deletion')),
        content: Text(tr('هل تريد حذف هذا العنصر؟', 'Delete this item?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(tr('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await mutate((repo) => repo.remove(table, row['id'] as int));
    }
  }

  Future<void> editTransaction([RowData? row, bool recurring = false]) async {
    final table = recurring ? 'recurring_transactions' : 'transactions';
    var kindValue = row?['type'] as String? ?? 'expense';
    var cat = row?['category_id'] as int?;
    var date = row == null
        ? DateTime(
            selected.year,
            selected.month,
            min(
              DateTime.now().day,
              DateTime(selected.year, selected.month + 1, 0).day,
            ),
          )
        : DateTime.parse(row['date'] as String);
    var note = row?['note'] as String? ?? '';
    int? amount;
    final result = await formDialog(
      recurring
          ? tr('جدولة معاملة شهرية', 'Schedule monthly transaction')
          : row == null
          ? tr('إضافة معاملة', 'Add transaction')
          : tr('تعديل المعاملة', 'Edit transaction'),
      (dialog, change) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'expense',
                label: Text(kind('expense')),
                icon: const Icon(Icons.north_east),
              ),
              ButtonSegment(
                value: 'income',
                label: Text(kind('income')),
                icon: const Icon(Icons.south_west),
              ),
            ],
            selected: {kindValue},
            onSelectionChanged: (value) => change(() {
              kindValue = value.single;
              cat = null;
            }),
          ),
          const SizedBox(height: 14),
          amountField(
            row == null
                ? null
                : ((row['amount'] as int) / 100).toStringAsFixed(2),
            (value) => amount = parseAmount(value!),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            key: ValueKey(kindValue),
            initialValue: cat,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('التصنيف', 'Category')),
            items: state.categories
                .where((c) => c['type'] == kindValue)
                .map(
                  (c) => DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text(state.name(c['id'] as int)),
                  ),
                )
                .toList(),
            validator: (value) =>
                value == null ? tr('اختر تصنيفًا', 'Select a category') : null,
            onChanged: (value) => cat = value,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: dialog,
                initialDate: date,
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              );
              if (picked != null && dialog.mounted) change(() => date = picked);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(day(date)),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: note,
            maxLength: 180,
            decoration: InputDecoration(
              labelText: tr('ملاحظة اختيارية', 'Optional note'),
            ),
            onSaved: (value) => note = value!.trim(),
          ),
        ],
      ),
      () => {
        'type': kindValue,
        'category_id': cat,
        'amount': amount,
        'note': note,
        if (recurring) ...{
          'start_date': day(date),
          'next_due_date': day(date),
        } else
          'date': day(date),
      },
      delete: row == null ? null : () => confirmRemove(table, row),
    );
    if (result != null && mounted) {
      await mutate((repo) => repo.save(table, result, row?['id'] as int?));
    }
  }

  Future<void> editBudget([RowData? row]) async {
    var cat = row?['category_id'] as int?;
    int? limit;
    final available = state.categories.where(
      (c) =>
          c['type'] == 'expense' &&
          !state.budgets.any(
            (b) => b['month'] == period && b['category_id'] == c['id'],
          ),
    );
    final overallAvailable = !state.budgets.any(
      (b) => b['month'] == period && b['category_id'] == null,
    );
    if (row == null && !overallAvailable && available.isEmpty) {
      notify(
        tr(
          'تم ضبط جميع حدود الإنفاق لهذا الشهر.',
          'All budget limits are set for this month.',
        ),
      );
      return;
    }
    if (row == null && !overallAvailable) cat = available.first['id'] as int;
    final result = await formDialog(
      tr('حد الإنفاق', 'Spending limit'),
      (_, change) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (row == null)
            DropdownButtonFormField<int>(
              initialValue: cat ?? 0,
              decoration: InputDecoration(
                labelText: tr('نطاق الميزانية', 'Budget scope'),
              ),
              items: [
                if (overallAvailable)
                  DropdownMenuItem(
                    value: 0,
                    child: Text(tr('الميزانية الإجمالية', 'Overall budget')),
                  ),
                for (final c in available)
                  DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text(state.name(c['id'] as int)),
                  ),
              ],
              onChanged: (value) => cat = value == 0 ? null : value,
            )
          else
            Text(
              cat == null
                  ? tr('الميزانية الإجمالية', 'Overall budget')
                  : state.name(cat!),
            ),
          const SizedBox(height: 14),
          amountField(
            row == null
                ? null
                : ((row['limit_amount'] as int) / 100).toStringAsFixed(2),
            (value) => limit = parseAmount(value!),
          ),
        ],
      ),
      () => {
        'month': period,
        'category_id': cat,
        'limit_amount': limit,
        'demo': 0,
      },
    );
    if (result != null && mounted) {
      await mutate((repo) => repo.save('budgets', result, row?['id'] as int?));
    }
  }

  Future<void> editCategory([RowData? row]) async {
    var kindValue = row?['type'] as String? ?? 'expense';
    var name = row?['name'] as String? ?? '';
    var icon = row?['icon'] as int? ?? 7;
    var color = row?['color'] as int? ?? 0;
    final result = await formDialog(
      tr('تصنيف مخصص', 'Custom category'),
      (_, change) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: name,
            maxLength: 45,
            decoration: InputDecoration(labelText: tr('الاسم', 'Name')),
            validator: (value) =>
                value!.trim().isEmpty ? tr('أدخل اسمًا', 'Enter a name') : null,
            onSaved: (value) => name = value!.trim(),
          ),
          if (row == null)
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'expense', label: Text(kind('expense'))),
                ButtonSegment(value: 'income', label: Text(kind('income'))),
              ],
              selected: {kindValue},
              onSelectionChanged: (v) => change(() => kindValue = v.single),
            ),
          const SizedBox(height: 14),
          Text(tr('الأيقونة', 'Icon')),
          Wrap(
            children: List.generate(
              icons.length,
              (i) => IconButton(
                isSelected: i == icon,
                selectedIcon: Icon(icons[i], color: palette[color]),
                icon: Icon(icons[i]),
                onPressed: () => change(() => icon = i),
              ),
            ),
          ),
          Text(tr('اللون', 'Color')),
          Wrap(
            spacing: 8,
            children: List.generate(
              palette.length,
              (i) => ChoiceChip(
                label: Icon(Icons.circle, color: palette[i], size: 15),
                selected: color == i,
                onSelected: (_) => change(() => color = i),
              ),
            ),
          ),
        ],
      ),
      () => {'type': kindValue, 'name': name, 'icon': icon, 'color': color},
    );
    if (result != null && mounted) {
      await mutate(
        (repo) => repo.save('categories', result, row?['id'] as int?),
      );
    }
  }

  void exportCsv() {
    String safe(String text) =>
        RegExp(r'^\s*[=+\-@]|^[\t\r\n]').hasMatch(text) ? "'$text" : text;
    final csv = const ListToCsvConverter().convert([
      [
        tr('التاريخ', 'Date'),
        tr('النوع', 'Type'),
        tr('التصنيف', 'Category'),
        'SAR',
        tr('ملاحظة', 'Note'),
        tr('تجريبي', 'Demo'),
      ],
      for (final row in rows)
        [
          row['date'],
          kind(row['type']),
          safe(state.name(row['category_id'] as int)),
          ((row['amount'] as int) / 100).toStringAsFixed(2),
          safe(row['note'] as String? ?? ''),
          row['demo'] == 1 ? tr('نعم', 'Yes') : '',
        ],
    ]);
    final data = utf8.encode('\uFEFF$csv');
    final blob = web.Blob(
      [data.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = url
      ..download = 'mizan-$period.csv'
      ..click();
    Future<void>.delayed(
      const Duration(seconds: 1),
      () => web.URL.revokeObjectURL(url),
    );
  }

  Future<void> exportPdf() async {
    try {
      final income = state.total(rows, 'income');
      final expense = state.total(rows, 'expense');
      final entries = breakdown(rows).entries
          .map((entry) => [state.name(entry.key), money(entry.value)])
          .toList();
      final rtl = state.ar;
      final filename = 'mizan-$period.pdf';
      final heading = tr('ميزان | التقرير الشهري', 'Mizan | Monthly report');
      final labels = [
        tr('الدخل', 'Income'),
        tr('المصروفات', 'Expenses'),
        tr('صافي الشهر', 'Monthly net'),
      ];
      final summary = [money(income), money(expense), money(income - expense)];
      final breakdownTitle = tr('توزيع المصروفات', 'Expense breakdown');
      final columns = [tr('التصنيف', 'Category'), tr('المجموع', 'Total')];
      final label = periodLabel;
      final font = pdf.Font.ttf(
        await rootBundle.load('assets/NotoSansArabic.ttf'),
      );
      final direction = rtl ? pdf.TextDirection.rtl : pdf.TextDirection.ltr;
      final report = pdf.Document(
        theme: pdf.ThemeData.withFont(base: font, bold: font),
      );
      report.addPage(
        pdf.MultiPage(
          textDirection: direction,
          build: (_) => [
            pdf.Header(level: 0, text: heading),
            pdf.Paragraph(text: label),
            pdf.TableHelper.fromTextArray(
              headers: labels,
              data: [summary],
              headerDirection: direction,
              tableDirection: direction,
            ),
            pdf.SizedBox(height: 20),
            pdf.Header(level: 1, text: breakdownTitle),
            pdf.TableHelper.fromTextArray(
              headers: columns,
              data: entries,
              headerDirection: direction,
              tableDirection: direction,
            ),
          ],
        ),
      );
      await Printing.sharePdf(bytes: await report.save(), filename: filename);
    } catch (_) {
      if (mounted) {
        notify(tr('تعذّر تصدير التقرير.', 'Could not export the report.'));
      }
    }
  }
}

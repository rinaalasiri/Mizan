# Mizan

Mizan is a Flutter web app for tracking personal income, expenses, and budgets in Saudi riyals (SAR). It supports English and Arabic, with light and dark themes. Financial data is stored locally in the browser using SQLite.

## Features

- Track income and expenses with a searchable, filterable transaction history.
- Organize transactions with built-in and custom categories.
- Set monthly and category budgets with alerts at 80% and when a limit is exceeded.
- Review spending by category and compare monthly trends.
- Schedule recurring transactions and export monthly reports as PDF or CSV.
- Load sample data from Settings to explore the app.

## Run locally

Open the project folder in VS Code. With Flutter and Chrome installed, run these commands in the terminal:

```bash
flutter pub get
flutter run -d chrome
```

## Tech stack

Flutter, Material 3, Provider, SQLite via WebAssembly, and fl_chart.
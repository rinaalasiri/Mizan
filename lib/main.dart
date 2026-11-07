import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'database/finance_database.dart';
import 'providers/finance_state.dart';
import 'repositories/finance_repository.dart';
import 'screens/finance_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late var ready = open();

  Future<FinanceState> open() async {
    final repository = FinanceRepository(await FinanceDatabase.open());
    await repository.generateDue(DateTime.now());
    final state = FinanceState(repository);
    await state.refresh();
    return state;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: ready,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return ChangeNotifierProvider.value(
          value: snapshot.data!,
          child: const Mizan(),
        );
      }
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'تعذّر فتح قاعدة البيانات المحلية | Local database unavailable',
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('${snapshot.error}'),
                      ),
                      FilledButton(
                        onPressed: () => setState(() => ready = open()),
                        child: const Text('إعادة المحاولة | Retry'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

class Mizan extends StatelessWidget {
  const Mizan({super.key});

  ThemeData theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff146751),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Noto Sans Arabic',
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfff3f6f3)
          : const Color(0xff111916),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FinanceState>();
    return MaterialApp(
      title: state.ar ? 'ميزان' : 'Mizan',
      debugShowCheckedModeBanner: false,
      locale: Locale(state.ar ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: state.dark ? ThemeMode.dark : ThemeMode.light,
      home: const FinanceShell(),
    );
  }
}

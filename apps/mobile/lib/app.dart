import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'features/connection/prefs.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/pairing/pair_screen.dart';

final _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
  GoRoute(path: '/pair', builder: (_, _) => const PairScreen()),
  GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
]);

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final mode = ref.watch(prefsProvider.select((p) => p.themeMode));
    return MaterialApp.router(
      title: s.t('appName'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      routerConfig: _router,
      // Material's built-in localizations are English-only (flutter_localizations
      // is not a dependency), so keep the framework locale fixed and flip the
      // layout direction for Arabic ourselves.
      locale: const Locale('en'),
      builder: (context, child) => Directionality(
        textDirection: s.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
    );
  }
}

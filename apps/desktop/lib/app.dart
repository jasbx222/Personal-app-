import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:material_ui/material_ui.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'features/server/server_controller.dart';
import 'features/settings/settings_controller.dart';
import 'features/shell/router.dart';
import 'features/shell/tray_service.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      LaunchAtStartup.instance.setup(appName: 'Phone2PC', appPath: Platform.resolvedExecutable);
      await ref.read(serverControllerProvider.notifier).start();
      try {
        await ref.read(trayServiceProvider).init();
      } catch (_) {
        // No tray available (e.g. some Linux desktops): the window stays usable.
      }
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(firstRun: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final mode = ref.watch(settingsProvider.select((x) => x.themeMode));
    ref.listen(stringsProvider, (_, _) => ref.read(trayServiceProvider).refreshMenu());
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
      routerConfig: ref.watch(routerProvider),
      // Material's own localizations are English-only (flutter_localizations is
      // not a dependency), so the framework locale stays 'en' and we flip the
      // layout direction ourselves.
      locale: const Locale('en'),
      builder: (context, child) => Directionality(
        textDirection: s.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
    );
  }
}

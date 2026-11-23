// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/legacy.dart';

import 'app.dart';
import 'core/paths.dart';
import 'features/history/history_controller.dart';
import 'features/settings/settings_controller.dart';
import 'features/settings/settings_model.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = appDataDir();
  final settingsStore = SettingsStore(dir);
  final settings = settingsStore.load();
  final historyStore = HistoryStore(dir);
  try {
    Directory(settings.saveDir).createSync(recursive: true);
  } catch (_) {}

  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true); // close button hides to tray
  final showAtStart = settings.firstRun || !settings.startMinimized || args.contains('--show');
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1000, 720),
      minimumSize: Size(720, 520),
      center: true,
      title: 'Phone2PC',
    ),
    () async {
      if (showAtStart) {
        await windowManager.show();
        await windowManager.focus();
      } else {
        await windowManager.hide();
      }
    },
  );

  await localNotifier.setup(appName: 'Phone2PC', shortcutPolicy: ShortcutPolicy.requireCreate);

  runApp(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(settingsStore),
      historyStoreProvider.overrideWithValue(historyStore),
    ],
    child: const App(),
  ));
}

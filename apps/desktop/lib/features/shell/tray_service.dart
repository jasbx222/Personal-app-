// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/legacy.dart';

import '../../core/strings.dart';
import '../server/server_controller.dart';
import 'router.dart';
import 'window_service.dart';

/// System tray icon + close-to-tray behaviour.
class TrayService with TrayListener, WindowListener {
  TrayService(this._ref);

  final Ref _ref;

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    await trayManager.setIcon(Platform.isWindows ? 'assets/icons/tray.ico' : 'assets/icons/tray.png');
    await refreshMenu();
  }

  Future<void> refreshMenu() async {
    final s = _ref.read(stringsProvider);
    await trayManager.setToolTip(s.t('appName'));
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: s.t('show')),
      MenuItem(key: 'pair', label: s.t('pair')),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: s.t('quit')),
    ]));
  }

  Future<void> quit() async {
    await _ref.read(serverControllerProvider.notifier).stop();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => showMainWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showMainWindow();
      case 'pair':
        showMainWindow();
        _ref.read(routerProvider).go('/pair');
      case 'quit':
        quit();
    }
  }

  /// The window's close button only hides it; "Quit" in the tray really exits.
  @override
  void onWindowClose() => hideMainWindow();
}

final trayServiceProvider = Provider<TrayService>((ref) => TrayService(ref));


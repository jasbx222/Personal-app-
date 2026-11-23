// ignore_for_file: deprecated_member_use
import 'package:window_manager/legacy.dart';

Future<void> showMainWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

Future<void> hideMainWindow() => windowManager.hide();

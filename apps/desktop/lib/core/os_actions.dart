import 'dart:io';

import 'paths.dart';

/// Opens a file or folder with the OS default handler.
Future<void> openPath(String path) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [path]);
  } else {
    await Process.run('xdg-open', [path]);
  }
}

/// Reveals a file in the system file manager.
Future<void> showInFolder(String path) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', ['/select,$path']);
  } else if (Platform.isMacOS) {
    await Process.run('open', ['-R', path]);
  } else {
    await Process.run('xdg-open', [parentDir(path)]);
  }
}

/// Opens an http(s) URL in the default browser. Other schemes are refused so a
/// received "link" can never launch a local program.
Future<bool> openUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
    return false;
  }
  final target = uri.toString();
  if (Platform.isWindows) {
    // `start` treats & as a command separator, so go through rundll32 instead.
    await Process.run('rundll32', ['url.dll,FileProtocolHandler', target]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [target]);
  } else {
    await Process.run('xdg-open', [target]);
  }
  return true;
}

/// Adds a Windows Firewall rule for [port] (shows a UAC prompt).
Future<void> addWindowsFirewallRule(int port) async {
  final args = 'advfirewall firewall add rule name=\\"Phone2PC\\" dir=in action=allow protocol=TCP localport=$port profile=private,domain';
  await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    'Start-Process netsh -Verb RunAs -WindowStyle Hidden -ArgumentList "$args"',
  ]);
}

String firewallCommand(int port) =>
    'netsh advfirewall firewall add rule name="Phone2PC" dir=in action=allow protocol=TCP localport=$port profile=private,domain';

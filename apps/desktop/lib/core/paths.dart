import 'dart:io';

final String sep = Platform.pathSeparator;

String joinPath(String a, String b) => a.endsWith(sep) ? '$a$b' : '$a$sep$b';

String homeDir() =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? Directory.current.path;

/// Per-user directory for settings and history.
Directory appDataDir() {
  final String base;
  if (Platform.isWindows) {
    base = Platform.environment['APPDATA'] ?? homeDir();
  } else if (Platform.isMacOS) {
    base = joinPath(homeDir(), 'Library${sep}Application Support');
  } else {
    base = Platform.environment['XDG_CONFIG_HOME'] ?? joinPath(homeDir(), '.config');
  }
  final dir = Directory(joinPath(base, 'Phone2PC'));
  dir.createSync(recursive: true);
  return dir;
}

String defaultSaveDir() => joinPath(joinPath(homeDir(), 'Downloads'), 'Phone2PC');

String parentDir(String path) {
  final i = path.lastIndexOf(sep);
  return i <= 0 ? path : path.substring(0, i);
}

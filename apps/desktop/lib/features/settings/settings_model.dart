import 'dart:convert';
import 'dart:io';

import 'package:shared/shared.dart';

import '../../core/paths.dart';

class Settings {
  const Settings({
    required this.saveDir,
    required this.autoCopy,
    required this.port,
    required this.token,
    required this.deviceName,
    this.launchAtStartup = false,
    this.startMinimized = true,
    this.language = 'system',
    this.themeMode = 'system',
    this.firstRun = true,
    this.firewallHandled = false,
  });

  final String saveDir;
  final bool autoCopy;
  final int port;
  final String token;
  final String deviceName;
  final bool launchAtStartup;
  final bool startMinimized;
  final String language; // system | en | ar
  final String themeMode; // system | light | dark
  final bool firstRun;
  final bool firewallHandled;

  Settings copyWith({
    String? saveDir,
    bool? autoCopy,
    int? port,
    String? token,
    String? deviceName,
    bool? launchAtStartup,
    bool? startMinimized,
    String? language,
    String? themeMode,
    bool? firstRun,
    bool? firewallHandled,
  }) =>
      Settings(
        saveDir: saveDir ?? this.saveDir,
        autoCopy: autoCopy ?? this.autoCopy,
        port: port ?? this.port,
        token: token ?? this.token,
        deviceName: deviceName ?? this.deviceName,
        launchAtStartup: launchAtStartup ?? this.launchAtStartup,
        startMinimized: startMinimized ?? this.startMinimized,
        language: language ?? this.language,
        themeMode: themeMode ?? this.themeMode,
        firstRun: firstRun ?? this.firstRun,
        firewallHandled: firewallHandled ?? this.firewallHandled,
      );

  Map<String, Object?> toJson() => {
        'saveDir': saveDir,
        'autoCopy': autoCopy,
        'port': port,
        'token': token,
        'deviceName': deviceName,
        'launchAtStartup': launchAtStartup,
        'startMinimized': startMinimized,
        'language': language,
        'themeMode': themeMode,
        'firstRun': firstRun,
        'firewallHandled': firewallHandled,
      };

  factory Settings.fromJson(Map<String, dynamic> j) {
    final d = Settings.defaults();
    return Settings(
      saveDir: j['saveDir'] as String? ?? d.saveDir,
      autoCopy: j['autoCopy'] as bool? ?? d.autoCopy,
      port: j['port'] as int? ?? d.port,
      token: (j['token'] as String?)?.isNotEmpty == true ? j['token'] as String : d.token,
      deviceName: j['deviceName'] as String? ?? d.deviceName,
      launchAtStartup: j['launchAtStartup'] as bool? ?? false,
      startMinimized: j['startMinimized'] as bool? ?? true,
      language: j['language'] as String? ?? 'system',
      themeMode: j['themeMode'] as String? ?? 'system',
      firstRun: j['firstRun'] as bool? ?? true,
      firewallHandled: j['firewallHandled'] as bool? ?? false,
    );
  }

  factory Settings.defaults() => Settings(
        saveDir: defaultSaveDir(),
        autoCopy: true,
        port: kDefaultPort,
        token: generateToken(),
        deviceName: Platform.localHostname,
      );
}

/// Reads/writes `settings.json` in the per-user app directory.
class SettingsStore {
  SettingsStore(Directory dir) : _file = File(joinPath(dir.path, 'settings.json'));

  final File _file;

  Settings load() {
    try {
      final j = jsonDecode(_file.readAsStringSync());
      if (j is Map<String, dynamic>) return Settings.fromJson(j);
    } catch (_) {}
    final s = Settings.defaults();
    save(s);
    return s;
  }

  void save(Settings s) {
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(s.toJson()), flush: true);
    tmp.renameSync(_file.path);
  }
}

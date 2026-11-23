import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../server/server_controller.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _port;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final st = ref.read(settingsProvider);
    _port = TextEditingController(text: '${st.port}');
    _name = TextEditingController(text: st.deviceName);
  }

  @override
  void dispose() {
    _port.dispose();
    _name.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _applyPort() async {
    final s = ref.read(stringsProvider);
    final p = int.tryParse(_port.text.trim());
    if (p == null || p < 1024 || p > 65535) {
      _snack(s.t('portInvalid'));
      return;
    }
    ref.read(settingsProvider.notifier).update((x) => x.copyWith(port: p));
    await ref.read(serverControllerProvider.notifier).start();
    _snack(s.t('portApplied', {'port': '$p'}));
  }

  Future<void> _applyName() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    ref.read(settingsProvider.notifier).update((x) => x.copyWith(deviceName: n));
    await ref.read(serverControllerProvider.notifier).start(); // re-advertise under the new name
  }

  Future<void> _setStartup(bool on) async {
    try {
      on ? await LaunchAtStartup.instance.enable() : await LaunchAtStartup.instance.disable();
      ref.read(settingsProvider.notifier).update((x) => x.copyWith(launchAtStartup: on));
    } catch (e) {
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final st = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const BackButtonIcon(), onPressed: () => context.go('/')),
        title: Text(s.t('settings')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(s.t('saveFolder')),
              subtitle: Directionality(textDirection: TextDirection.ltr, child: Text(st.saveDir)),
              trailing: OutlinedButton(
                child: Text(s.t('chooseFolder')),
                onPressed: () async {
                  final dir = await FilePicker.platform.getDirectoryPath();
                  if (dir != null) ctl.update((x) => x.copyWith(saveDir: dir));
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.content_paste),
              title: Text(s.t('autoCopy')),
              subtitle: Text(s.t('autoCopySub')),
              value: st.autoCopy,
              onChanged: (v) => ctl.update((x) => x.copyWith(autoCopy: v)),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.power_settings_new),
              title: Text(s.t('launchAtStartup')),
              value: st.launchAtStartup,
              onChanged: _setStartup,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.minimize),
              title: Text(s.t('startMinimized')),
              value: st.startMinimized,
              onChanged: (v) => ctl.update((x) => x.copyWith(startMinimized: v)),
            ),
            const Divider(height: 32),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: s.t('deviceName')),
                  onSubmitted: (_) => _applyName(),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: _applyName, child: Text(s.t('apply'))),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.t('port')),
                  onSubmitted: (_) => _applyPort(),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: _applyPort, child: Text(s.t('apply'))),
            ]),
            const Divider(height: 32),
            _DropdownRow(
              label: s.t('language'),
              value: st.language,
              items: {'system': s.t('system'), 'en': s.t('english'), 'ar': s.t('arabic')},
              onChanged: (v) => ctl.update((x) => x.copyWith(language: v)),
            ),
            const SizedBox(height: 12),
            _DropdownRow(
              label: s.t('theme'),
              value: st.themeMode,
              items: {'system': s.t('system'), 'light': s.t('light'), 'dark': s.t('dark')},
              onChanged: (v) => ctl.update((x) => x.copyWith(themeMode: v)),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(s.t('showQr')),
              onTap: () => context.go('/pair'),
            ),
            ListTile(
              leading: Icon(Icons.link_off, color: Theme.of(context).colorScheme.error),
              title: Text(s.t('revoke')),
              onTap: () => context.go('/pair'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            isExpanded: true,
            items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ),
      );
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../connection/connection_controller.dart';
import '../connection/prefs.dart';
import '../share/share_handler.dart';
import '../transfers/transfers_controller.dart';
import 'transfer_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _text = TextEditingController();
  late final AppLifecycleListener _lifecycle;
  ShareHandler? _share;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(connectionProvider.notifier).check());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _share = ShareHandler(ref.read(transfersProvider.notifier), () {
        if (mounted) ref.read(connectionProvider.notifier).check();
      })..start();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _share?.dispose();
    _text.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _sendTyped() {
    ref.read(transfersProvider.notifier).sendText(_text.text);
    _text.clear();
  }

  Future<void> _sendClipboard() async {
    final s = ref.read(stringsProvider);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text?.trim() ?? '';
    if (t.isEmpty) {
      _snack(s.t('clipboardEmpty'));
      return;
    }
    ref.read(transfersProvider.notifier).sendText(t);
  }

  Future<void> _pickGallery() async {
    final files = await ImagePicker().pickMultipleMedia();
    if (files.isNotEmpty) ref.read(transfersProvider.notifier).sendFiles(files.map((f) => f.path));
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles(); // multi-select
    if (files.isEmpty) return;
    ref.read(transfersProvider.notifier).sendFiles(files.map((f) => f.path).whereType<String>());
  }

  Future<void> _takePhoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.camera);
    if (f != null) ref.read(transfersProvider.notifier).sendFiles([f.path]);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final conn = ref.watch(connectionProvider);
    final tasks = ref.watch(transfersProvider);
    final scheme = Theme.of(context).colorScheme;
    final canSend = conn.status != LinkStatus.unpaired;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('appName')),
        actions: [
          IconButton(tooltip: s.t('history'), icon: const Icon(Icons.history), onPressed: () => context.push('/history')),
          IconButton(tooltip: s.t('settings'), icon: const Icon(Icons.tune), onPressed: () => _showSettings(context)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(conn: conn),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textDirection: null,
              decoration: InputDecoration(hintText: s.t('textHint')),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canSend ? _sendClipboard : null,
                  icon: const Icon(Icons.content_paste_go),
                  label: Text(s.t('sendClipboard')),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: canSend && _text.text.trim().isNotEmpty ? _sendTyped : null,
                icon: const Icon(Icons.send),
                label: Text(s.t('send')),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _PickButton(icon: Icons.photo_library_outlined, label: s.t('gallery'), onTap: canSend ? _pickGallery : null)),
              const SizedBox(width: 8),
              Expanded(child: _PickButton(icon: Icons.attach_file, label: s.t('files'), onTap: canSend ? _pickFiles : null)),
              const SizedBox(width: 8),
              Expanded(child: _PickButton(icon: Icons.photo_camera_outlined, label: s.t('camera'), onTap: canSend ? _takePhoto : null)),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: Text(s.t('transfers'), style: Theme.of(context).textTheme.titleMedium)),
              if (tasks.any((t) => t.status == TaskStatus.done || t.status == TaskStatus.failed || t.status == TaskStatus.cancelled))
                TextButton(onPressed: ref.read(transfersProvider.notifier).clearFinished, child: Text(s.t('clearFinished'))),
            ]),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(s.t('noTransfers'), style: TextStyle(color: scheme.onSurfaceVariant))),
              )
            else
              for (final t in tasks) TransferTile(key: ValueKey(t.id), task: t),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => const _SettingsSheet());
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ]),
      );
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.conn});

  final LinkState conn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final (color, icon, title, hint) = switch (conn.status) {
      LinkStatus.connected => (Colors.green, Icons.check_circle, s.t('statusConnected'), null),
      LinkStatus.searching => (scheme.primary, Icons.sync, s.t('statusSearching'), null),
      LinkStatus.offline => (scheme.error, Icons.wifi_off, s.t('statusOffline'), s.t('offlineHint')),
      LinkStatus.unpaired => (scheme.outline, Icons.link_off, s.t('statusUnpaired'), s.t('unpairedHint')),
      LinkStatus.tokenInvalid => (scheme.error, Icons.lock_outline, s.t('statusTokenInvalid'), s.t('tokenInvalidHint')),
    };
    final p = conn.pairing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p?.name ?? s.t('appName'), style: Theme.of(context).textTheme.titleMedium),
                Text(title, style: TextStyle(color: color)),
              ]),
            ),
            if (conn.status == LinkStatus.offline)
              IconButton(tooltip: s.t('retry'), icon: const Icon(Icons.refresh), onPressed: ref.read(connectionProvider.notifier).check),
          ]),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          if (conn.status == LinkStatus.unpaired || conn.status == LinkStatus.tokenInvalid) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/pair'),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(conn.status == LinkStatus.unpaired ? s.t('scanQr') : s.t('pairAgain')),
            ),
          ],
        ]),
      ),
    );
  }
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final prefs = ref.watch(prefsProvider);
    final ctl = ref.read(prefsProvider.notifier);
    final paired = ref.watch(connectionProvider).pairing != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('language'), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'system', label: Text(s.t('system'))),
              ButtonSegment(value: 'en', label: Text(s.t('english'))),
              ButtonSegment(value: 'ar', label: Text(s.t('arabic'))),
            ],
            selected: {prefs.language},
            onSelectionChanged: (v) => ctl.update((p) => p.copyWith(language: v.first)),
          ),
          const SizedBox(height: 16),
          Text(s.t('theme'), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'system', label: Text(s.t('system'))),
              ButtonSegment(value: 'light', label: Text(s.t('light'))),
              ButtonSegment(value: 'dark', label: Text(s.t('dark'))),
            ],
            selected: {prefs.themeMode},
            onSelectionChanged: (v) => ctl.update((p) => p.copyWith(themeMode: v.first)),
          ),
          if (paired) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                ref.read(connectionProvider.notifier).unpair();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.link_off),
              label: Text(s.t('unpair')),
            ),
          ],
        ]),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../../core/bidi.dart';
import '../../core/os_actions.dart';
import '../../core/strings.dart';
import '../server/server_controller.dart';
import '../settings/settings_controller.dart';
import '../shell/firewall_dialog.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.highlightId});

  final String? highlightId;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isWindows && !ref.read(settingsProvider).firewallHandled) {
        showFirewallDialog(context, ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final items = ref.watch(historyProvider);
    final server = ref.watch(serverControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    final status = server.running
        ? s.t('serverRunning', {
            'addr': server.addresses.isEmpty
                ? ':${server.port}'
                : '${server.addresses.first.ip}:${server.port}'
          })
        : server.error != null
            ? s.t('serverError', {'err': server.error!})
            : s.t('serverStopped');

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('history')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Center(
              child: Chip(
                avatar: Icon(Icons.circle, size: 12, color: server.running ? Colors.green : scheme.error),
                label: Text(status),
              ),
            ),
          ),
          IconButton(tooltip: s.t('pair'), icon: const Icon(Icons.qr_code_2), onPressed: () => context.go('/pair')),
          IconButton(tooltip: s.t('settings'), icon: const Icon(Icons.settings_outlined), onPressed: () => context.go('/settings')),
          const SizedBox(width: 8),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.phone_android, size: 64, color: scheme.outline),
                const SizedBox(height: 12),
                Text(s.t('emptyTitle'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(s.t('emptyBody'), style: TextStyle(color: scheme.onSurfaceVariant)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => HistoryTile(item: items[i], highlighted: items[i].id == widget.highlightId),
            ),
    );
  }
}

class HistoryTile extends ConsumerWidget {
  const HistoryTile({super.key, required this.item, this.highlighted = false});

  final HistoryItem item;
  final bool highlighted;

  void _snack(BuildContext c, String msg) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  bool get _fileExists => item.path != null && File(item.path!).existsSync();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final isText = item.kind.isText;

    Widget leading;
    if (item.kind == ItemKind.image && item.path != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(item.path!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          cacheWidth: 112, // decode small: thumbnails of 20 MP photos stay cheap
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 40),
        ),
      );
    } else {
      leading = Icon(
        switch (item.kind) {
          ItemKind.text => Icons.notes,
          ItemKind.link => Icons.link,
          ItemKind.image => Icons.image_outlined,
          ItemKind.video => Icons.videocam_outlined,
          ItemKind.file => Icons.insert_drive_file_outlined,
        },
        size: 40,
        color: scheme.primary,
      );
    }

    final title = isText ? (item.text ?? '') : (item.name ?? '');
    final dir = directionFor(title);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlighted ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 56, height: 56, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(
                title,
                maxLines: isText ? 4 : 2,
                textDirection: dir,
                textAlign: TextAlign.start,
                style: item.kind == ItemKind.link
                    ? TextStyle(color: scheme.primary, decoration: TextDecoration.underline)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (!isText) formatBytes(item.size),
                  _formatTime(item.receivedAt),
                ].join(' · '),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ]),
          ),
          Wrap(spacing: 0, children: [
            IconButton(
              tooltip: s.t('copy'),
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: isText ? item.text! : (item.path ?? '')));
                if (context.mounted) _snack(context, s.t(isText ? 'copied' : 'pathCopied'));
              },
            ),
            if (item.kind == ItemKind.link)
              IconButton(
                tooltip: s.t('openInBrowser'),
                icon: const Icon(Icons.open_in_browser),
                onPressed: () async {
                  if (!await openUrl(item.text ?? '') && context.mounted) _snack(context, s.t('badLink'));
                },
              ),
            if (!isText) ...[
              IconButton(
                tooltip: s.t('open'),
                icon: const Icon(Icons.open_in_new),
                onPressed: () {
                  if (_fileExists) {
                    openPath(item.path!);
                  } else {
                    _snack(context, s.t('fileMissing'));
                  }
                },
              ),
              IconButton(
                tooltip: s.t('showInFolder'),
                icon: const Icon(Icons.folder_open_outlined),
                onPressed: () {
                  if (_fileExists) {
                    showInFolder(item.path!);
                  } else {
                    _snack(context, s.t('fileMissing'));
                  }
                },
              ),
            ],
            IconButton(
              tooltip: s.t('delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.t('deleteTitle')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, 'list'), child: Text(s.t('removeFromList'))),
          if (!item.kind.isText && item.path != null)
            FilledButton(onPressed: () => Navigator.pop(context, 'file'), child: Text(s.t('deleteFileToo'))),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == 'file' && item.path != null) {
      try {
        File(item.path!).deleteSync();
      } catch (_) {}
    }
    ref.read(historyProvider.notifier).remove(item.id);
  }
}

String _formatTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dateFolderName(t)} ${two(t.hour)}:${two(t.minute)}';
}

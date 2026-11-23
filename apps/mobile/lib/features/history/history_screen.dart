import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../../core/bidi.dart';
import '../../core/strings.dart';
import '../home/transfer_tile.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final items = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('history')),
        actions: [
          if (items.isNotEmpty)
            IconButton(tooltip: s.t('clearHistory'), icon: const Icon(Icons.delete_sweep_outlined), onPressed: ref.read(historyProvider.notifier).clear),
        ],
      ),
      body: items.isEmpty
          ? Center(child: Text(s.t('historyEmpty')))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = items[i];
                final t = e.sentAt;
                String two(int n) => n.toString().padLeft(2, '0');
                return ListTile(
                  leading: Icon(iconForKind(e.kind)),
                  title: Text(e.label, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: directionFor(e.label), textAlign: TextAlign.start),
                  subtitle: Text('${dateFolderName(t)} ${two(t.hour)}:${two(t.minute)}${e.kind.isText ? '' : ' · ${formatBytes(e.size)}'}'),
                );
              },
            ),
    );
  }
}

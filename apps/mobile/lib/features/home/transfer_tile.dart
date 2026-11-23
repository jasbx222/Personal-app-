import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

import '../../core/bidi.dart';
import '../../core/strings.dart';
import '../connection/api_client.dart';
import '../transfers/transfers_controller.dart';

IconData iconForKind(ItemKind k) => switch (k) {
      ItemKind.text => Icons.notes,
      ItemKind.link => Icons.link,
      ItemKind.image => Icons.image_outlined,
      ItemKind.video => Icons.videocam_outlined,
      ItemKind.file => Icons.insert_drive_file_outlined,
    };

class TransferTile extends ConsumerWidget {
  const TransferTile({super.key, required this.task});

  final TransferTask task;

  String _error(Strings s) => switch (task.failure) {
        FailureKind.notPaired => s.t('errNotPaired'),
        FailureKind.unreachable => s.t('errUnreachable'),
        FailureKind.unauthorized => s.t('errUnauthorized'),
        FailureKind.fileMissing => s.t('errFileMissing'),
        FailureKind.server => s.t('errServer', {'err': task.detail ?? '?'}),
        _ => s.t('errInterrupted'),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final ctl = ref.read(transfersProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final pct = ((task.progress ?? 0) * 100).round();

    final (statusText, statusColor) = switch (task.status) {
      TaskStatus.queued => (s.t('waiting'), scheme.onSurfaceVariant),
      TaskStatus.uploading => (task.total > 0 && task.path != null ? s.t('sending', {'pct': '$pct'}) : s.t('waiting'), scheme.primary),
      TaskStatus.done => (s.t('sent'), Colors.green),
      TaskStatus.failed => (_error(s), scheme.error),
      TaskStatus.cancelled => (s.t('cancelled'), scheme.onSurfaceVariant),
    };

    final active = task.status == TaskStatus.queued || task.status == TaskStatus.uploading;
    final canRetry = task.status == TaskStatus.failed || task.status == TaskStatus.cancelled;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
        child: Row(children: [
          Icon(iconForKind(task.kind), color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.label, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: directionFor(task.label), textAlign: TextAlign.start),
              const SizedBox(height: 2),
              Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
              if (task.status == TaskStatus.uploading && task.path != null) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(value: task.progress, borderRadius: BorderRadius.circular(4)),
              ],
            ]),
          ),
          if (active) IconButton(tooltip: s.t('cancel'), icon: const Icon(Icons.close), onPressed: () => ctl.cancel(task.id)),
          if (canRetry) IconButton(tooltip: s.t('retry'), icon: const Icon(Icons.refresh), onPressed: () => ctl.retry(task.id)),
          if (!active) IconButton(tooltip: s.t('remove'), icon: const Icon(Icons.delete_outline), onPressed: () => ctl.remove(task.id)),
        ]),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared/shared.dart';

import '../../core/strings.dart';
import 'router.dart';
import 'window_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService(ref));

class NotificationService {
  NotificationService(this._ref);

  final Ref _ref;
  final _live = <LocalNotification>{}; // keep references so click callbacks survive

  Future<void> notifyReceived(HistoryItem item) async {
    final s = _ref.read(stringsProvider);
    final body = item.kind.isText
        ? (item.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim()
        : '${item.name ?? ''} · ${formatBytes(item.size)}';
    final n = LocalNotification(
      title: s.t('received'),
      body: body.length > 140 ? '${body.substring(0, 140)}…' : body,
    );
    n.onClick = () {
      _live.remove(n);
      showMainWindow();
      _ref.read(routerProvider).go('/?item=${Uri.encodeQueryComponent(item.id)}');
    };
    n.onClose = (_) => _live.remove(n);
    _live.add(n);
    try {
      await n.show();
    } catch (_) {
      _live.remove(n);
    }
  }
}

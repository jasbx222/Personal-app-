import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared/shared.dart';

import '../transfers/transfers_controller.dart';

/// Receives content shared from other apps ("Share → Phone2PC") and sends it
/// to the PC immediately, both on cold start and while the app is running.
class ShareHandler {
  ShareHandler(this._transfers, this._onShared);

  final TransfersController _transfers;
  final void Function() _onShared;
  StreamSubscription<List<SharedMediaFile>>? _sub;

  Future<void> start() async {
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      _handle(initial);
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_handle, onError: (_) {});
    } catch (_) {
      // Plugin unavailable (e.g. iOS without the share extension): in-app sending still works.
    }
  }

  void _handle(List<SharedMediaFile> items) {
    if (items.isEmpty) return;
    final files = <String>[];
    for (final m in items) {
      switch (m.type) {
        case SharedMediaType.text || SharedMediaType.url:
          _transfers.sendText(m.path, type: isProbablyUrl(m.path.trim()) ? ItemKind.link : ItemKind.text);
        default:
          files.add(m.path.startsWith('file://') ? Uri.parse(m.path).toFilePath() : m.path);
      }
    }
    if (files.isNotEmpty) _transfers.sendFiles(files);
    ReceiveSharingIntent.instance.reset();
    _onShared();
  }

  void dispose() => _sub?.cancel();
}

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../history/history_controller.dart';
import '../settings/settings_controller.dart';
import '../shell/notification_service.dart';
import 'discovery.dart';
import 'network_info.dart';
import 'transfer_server.dart';

class ServerState {
  const ServerState({this.running = false, this.port, this.error, this.addresses = const []});

  final bool running;
  final int? port;
  final String? error;
  final List<LanAddress> addresses;
}

final serverControllerProvider = NotifierProvider<ServerController, ServerState>(ServerController.new);

class ServerController extends Notifier<ServerState> {
  TransferServer? _server;
  final _advertiser = DiscoveryAdvertiser();

  @override
  ServerState build() => const ServerState();

  Future<void> start() async {
    await stop();
    final s = ref.read(settingsProvider);
    final server = TransferServer(
      token: () => ref.read(settingsProvider).token,
      saveDir: () => ref.read(settingsProvider).saveDir,
      deviceName: () => ref.read(settingsProvider).deviceName,
      recent: () => ref.read(historyProvider),
      onItem: _onItem,
    );
    final addresses = await lanAddresses();
    try {
      await server.start(s.port);
      _server = server;
      state = ServerState(running: true, port: s.port, addresses: addresses);
    } catch (e) {
      state = ServerState(error: '$e', addresses: addresses);
      return;
    }
    try {
      await _advertiser.start(name: s.deviceName, port: s.port);
    } catch (_) {
      // mDNS is best-effort.
    }
  }

  Future<void> stop() async {
    await _advertiser.stop();
    await _server?.stop();
    _server = null;
    state = ServerState(addresses: state.addresses);
  }

  Future<void> refreshAddresses() async {
    state = ServerState(
      running: state.running,
      port: state.port,
      error: state.error,
      addresses: await lanAddresses(),
    );
  }

  Future<void> _onItem(HistoryItem item) async {
    ref.read(historyProvider.notifier).add(item);
    if (item.kind.isText && ref.read(settingsProvider).autoCopy && item.text != null) {
      await Clipboard.setData(ClipboardData(text: item.text!));
    }
    await ref.read(notificationServiceProvider).notifyReceived(item);
  }
}

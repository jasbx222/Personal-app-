import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'discovery.dart';
import 'prefs.dart';

enum LinkStatus { unpaired, searching, connected, offline, tokenInvalid }

class LinkState {
  const LinkState({this.status = LinkStatus.searching, this.pairing, this.loaded = false});

  final LinkStatus status;
  final Pairing? pairing;
  final bool loaded;

  LinkState copyWith({LinkStatus? status, Pairing? pairing, bool? loaded, bool clearPairing = false}) =>
      LinkState(
        status: status ?? this.status,
        pairing: clearPairing ? null : (pairing ?? this.pairing),
        loaded: loaded ?? this.loaded,
      );
}

final connectionProvider = NotifierProvider<ConnectionController, LinkState>(ConnectionController.new);

class ConnectionController extends Notifier<LinkState> {
  Timer? _timer;
  bool _checking = false;

  @override
  LinkState build() {
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(_init);
    return const LinkState();
  }

  Future<void> _init() async {
    final p = Pairing.fromJson(await ref.read(vaultProvider).read('pairing'));
    state = LinkState(
      status: p == null ? LinkStatus.unpaired : LinkStatus.searching,
      pairing: p,
      loaded: true,
    );
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => check());
    if (p != null) await check();
  }

  ApiClient? get client => state.pairing == null ? null : ApiClient(state.pairing!);

  /// Verifies the connection; if the saved address is dead, looks the PC up
  /// on mDNS (its IP may have changed) before giving up.
  Future<void> check() async {
    final p = state.pairing;
    if (p == null || _checking) return;
    _checking = true;
    try {
      if (state.status != LinkStatus.connected) state = state.copyWith(status: LinkStatus.searching);
      switch (await _tryPing(p)) {
        case _Ping.ok:
          state = state.copyWith(status: LinkStatus.connected);
          return;
        case _Ping.unauthorized:
          state = state.copyWith(status: LinkStatus.tokenInvalid);
          return;
        case _Ping.unreachable:
          break;
      }
      state = state.copyWith(status: LinkStatus.searching);
      final hits = await scanForDesktops(stopWhen: (d) => d.name == p.name);
      final match = hits.where((d) => d.name == p.name).firstOrNull;
      if (match != null) {
        final moved = p.copyWith(host: match.host, port: match.port);
        if (await _tryPing(moved) == _Ping.ok) {
          await _save(moved);
          state = state.copyWith(status: LinkStatus.connected, pairing: moved);
          return;
        }
      }
      state = state.copyWith(status: LinkStatus.offline);
    } finally {
      _checking = false;
    }
  }

  Future<_Ping> _tryPing(Pairing p) async {
    try {
      await ApiClient(p).ping();
      return _Ping.ok;
    } on TransferFailure catch (e) {
      return e.kind == FailureKind.unauthorized ? _Ping.unauthorized : _Ping.unreachable;
    } catch (_) {
      return _Ping.unreachable;
    }
  }

  /// Saves [p] after confirming the desktop accepts it. Throws [TransferFailure].
  Future<Pairing> pair(Pairing p) async {
    final ping = await ApiClient(p).ping(timeout: const Duration(seconds: 6));
    final named = p.copyWith(name: ping.deviceName);
    await _save(named);
    state = LinkState(status: LinkStatus.connected, pairing: named, loaded: true);
    return named;
  }

  Future<void> unpair() async {
    await ref.read(vaultProvider).delete('pairing');
    state = const LinkState(status: LinkStatus.unpaired, loaded: true);
  }

  /// Called by transfers when the desktop answers 401 / can't be reached.
  void reportFailure(FailureKind kind) {
    if (kind == FailureKind.unauthorized) {
      state = state.copyWith(status: LinkStatus.tokenInvalid);
    } else if (kind == FailureKind.unreachable || kind == FailureKind.interrupted) {
      check();
    }
  }

  Future<void> _save(Pairing p) => ref.read(vaultProvider).write('pairing', p.toJson());
}

enum _Ping { ok, unauthorized, unreachable }

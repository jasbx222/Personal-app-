import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:shared/shared.dart';

class FoundDesktop {
  const FoundDesktop({required this.name, required this.host, required this.port});
  final String name;
  final String host;
  final int port;
}

/// One-shot mDNS scan for desktops advertising `_phone2pc._tcp`.
///
/// Completes after [timeout], or early as soon as [stopWhen] accepts a result.
Future<List<FoundDesktop>> scanForDesktops({
  Duration timeout = const Duration(seconds: 5),
  bool Function(FoundDesktop)? stopWhen,
}) async {
  final found = <String, FoundDesktop>{};
  final done = Completer<void>();
  final discovery = BonsoirDiscovery(type: kServiceType);
  StreamSubscription<BonsoirDiscoveryEvent>? sub;
  try {
    await discovery.initialize();
    sub = discovery.eventStream!.listen((e) {
      switch (e) {
        case BonsoirDiscoveryServiceFoundEvent():
          e.service.resolve(discovery.serviceResolver);
        case BonsoirDiscoveryServiceResolvedEvent() || BonsoirDiscoveryServiceUpdatedEvent():
          final s = e.service!;
          final ip = s.hostAddresses.firstWhere(
            (a) => RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(a),
            orElse: () => '',
          );
          final host = ip.isNotEmpty ? ip : (s.hostname ?? '');
          if (host.isEmpty) return;
          final d = FoundDesktop(name: s.name, host: host, port: s.port);
          found[s.name] = d;
          if (stopWhen?.call(d) == true && !done.isCompleted) done.complete();
        default:
          break;
      }
    });
    await discovery.start();
    await Future.any([done.future, Future<void>.delayed(timeout)]);
  } catch (_) {
    // mDNS unavailable (permissions, multicast blocked…): caller falls back to manual IP.
  } finally {
    await sub?.cancel();
    try {
      await discovery.stop();
    } catch (_) {}
  }
  return found.values.toList();
}

import 'package:bonsoir/bonsoir.dart';
import 'package:shared/shared.dart';

/// Advertises the receiver over mDNS/Bonjour. Failures are non-fatal: manual
/// IP entry on the phone still works.
class DiscoveryAdvertiser {
  BonsoirBroadcast? _broadcast;

  Future<void> start({required String name, required int port}) async {
    await stop();
    final service = BonsoirService(
      name: name,
      type: kServiceType,
      port: port,
      attributes: {'app': kAppId, 'v': kApiVersion},
    );
    final b = BonsoirBroadcast(service: service);
    await b.initialize();
    await b.start();
    _broadcast = b;
  }

  Future<void> stop() async {
    final b = _broadcast;
    _broadcast = null;
    try {
      await b?.stop();
    } catch (_) {}
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared/shared.dart';

import '../../core/strings.dart';
import '../connection/api_client.dart';
import '../connection/connection_controller.dart';
import '../connection/discovery.dart';

class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '$kDefaultPort');
  final _token = TextEditingController();
  bool _busy = false;
  bool _searching = false;
  List<FoundDesktop> _nearby = const [];

  @override
  void dispose() {
    _scanner.dispose();
    _ip.dispose();
    _port.dispose();
    _token.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _failureText(Strings s, TransferFailure e) => switch (e.kind) {
        FailureKind.unauthorized => s.t('errUnauthorized'),
        FailureKind.server => s.t('errServer', {'err': e.detail ?? '?'}),
        _ => s.t('errUnreachable'),
      };

  Future<void> _pair(Pairing p) async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      final done = await ref.read(connectionProvider.notifier).pair(p);
      if (!mounted) return;
      _snack(s.t('paired', {'name': done.name}));
      context.pop();
    } on TransferFailure catch (e) {
      if (mounted) _snack(_failureText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final p = PairingPayload.tryDecode(raw);
      if (p == null) {
        _snack(s.t('invalidQr'));
        return;
      }
      _pair(Pairing(host: p.ip, port: p.port, name: p.deviceName, token: p.token));
      return;
    }
  }

  void _pairManual() {
    final s = ref.read(stringsProvider);
    final port = int.tryParse(_port.text.trim());
    final ip = _ip.text.trim();
    final token = _token.text.trim();
    if (ip.isEmpty || token.isEmpty || port == null || port < 1 || port > 65535) {
      _snack(s.t('invalidInput'));
      return;
    }
    _pair(Pairing(host: ip, port: port, name: ip, token: token));
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final r = await scanForDesktops();
    if (mounted) {
      setState(() {
        _nearby = r;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('pairTitle'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(s.t('pairScanHelp'), style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 300,
              child: MobileScanner(
                controller: _scanner,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Container(
                  color: scheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(s.t('cameraDenied'), textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text(s.t('manualEntry')),
            childrenPadding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _searching ? null : _search,
                  icon: _searching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(s.t('searchNearby')),
                ),
              ),
              if (_nearby.isNotEmpty)
                Wrap(spacing: 8, children: [
                  for (final d in _nearby)
                    ActionChip(
                      avatar: const Icon(Icons.computer, size: 18),
                      label: Text(d.name),
                      onPressed: () => setState(() {
                        _ip.text = d.host;
                        _port.text = '${d.port}';
                      }),
                    ),
                ]),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ip,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: s.t('ip'), hintText: '192.168.1.20'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(controller: _port, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.t('port'))),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: _token, autocorrect: false, decoration: InputDecoration(labelText: s.t('token'))),
                ]),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(onPressed: _busy ? null : _pairManual, child: Text(s.t('pair'))),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

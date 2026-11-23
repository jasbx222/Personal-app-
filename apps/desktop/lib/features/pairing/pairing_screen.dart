import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared/shared.dart';

import '../../core/strings.dart';
import '../server/server_controller.dart';
import '../settings/settings_controller.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(serverControllerProvider.notifier).refreshAddresses());
  }

  Future<void> revoke() async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('revokeTitle')),
        content: Text(s.t('revokeBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('revokeConfirm'))),
        ],
      ),
    );
    if (ok == true) {
      ref.read(settingsProvider.notifier).revokePairing();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('newCodeCreated'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final server = ref.watch(serverControllerProvider);
    final addrs = server.addresses;
    final idx = _selected.clamp(0, addrs.isEmpty ? 0 : addrs.length - 1);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const BackButtonIcon(), onPressed: () => context.go('/')),
        title: Text(s.t('pairTitle')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: addrs.isEmpty
                ? Text(s.t('noNetwork'), textAlign: TextAlign.center)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.t('pairHelp'), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: QrImageView(
                        data: PairingPayload(
                          ip: addrs[idx].ip,
                          port: settings.port,
                          deviceName: settings.deviceName,
                          token: settings.token,
                        ).encode(),
                        size: 260,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    if (addrs.length > 1) ...[
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, children: [
                        for (var i = 0; i < addrs.length; i++)
                          ChoiceChip(
                            label: Text('${addrs[i].ip} (${addrs[i].interfaceName})'),
                            selected: i == idx,
                            onSelected: (_) => setState(() => _selected = i),
                          ),
                      ]),
                    ],
                    const SizedBox(height: 20),
                    ExpansionTile(
                      title: Text(s.t('manualDetails')),
                      children: [
                        _CopyRow(label: s.t('address'), value: '${addrs[idx].ip}:${settings.port}'),
                        _CopyRow(label: s.t('token'), value: settings.token),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: revoke,
                      icon: const Icon(Icons.link_off),
                      label: Text(s.t('revoke')),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        title: Text(label),
        subtitle: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy_outlined),
          onPressed: () => Clipboard.setData(ClipboardData(text: value)),
        ),
      );
}

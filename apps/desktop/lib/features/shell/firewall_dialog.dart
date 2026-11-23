import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/os_actions.dart';
import '../../core/strings.dart';
import '../settings/settings_controller.dart';

/// First-run help for Windows Firewall.
Future<void> showFirewallDialog(BuildContext context, WidgetRef ref) async {
  final s = ref.read(stringsProvider);
  final port = ref.read(settingsProvider).port;
  final cmd = firewallCommand(port);
  void markHandled() =>
      ref.read(settingsProvider.notifier).update((x) => x.copyWith(firewallHandled: true));

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.t('firewallTitle')),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('firewallBody', {'port': '$port'})),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(cmd, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('firewallLater'))),
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: cmd)),
          child: Text(s.t('copy')),
        ),
        FilledButton(
          onPressed: () async {
            await addWindowsFirewallRule(port);
            markHandled();
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(s.t('firewallAdd')),
        ),
      ],
    ),
  );
}

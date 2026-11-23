import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'settings_model.dart';

/// Overridden in `main()` with the store opened at startup.
final settingsStoreProvider = Provider<SettingsStore>((_) => throw UnimplementedError());

final settingsProvider = NotifierProvider<SettingsController, Settings>(SettingsController.new);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.read(settingsStoreProvider).load();

  void update(Settings Function(Settings s) change) {
    state = change(state);
    ref.read(settingsStoreProvider).save(state);
  }

  /// Invalidates the current pairing: every phone using the old token is
  /// rejected from the next request on.
  void revokePairing() => update((s) => s.copyWith(token: generateToken()));
}

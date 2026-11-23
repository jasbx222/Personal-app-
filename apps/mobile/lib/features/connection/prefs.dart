import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vault.dart';

final vaultProvider = Provider<Vault>((_) => Vault());

class Prefs {
  const Prefs({this.language = 'system', this.themeMode = 'system'});
  final String language; // system | en | ar
  final String themeMode; // system | light | dark

  Prefs copyWith({String? language, String? themeMode}) =>
      Prefs(language: language ?? this.language, themeMode: themeMode ?? this.themeMode);
}

final prefsProvider = NotifierProvider<PrefsController, Prefs>(PrefsController.new);

class PrefsController extends Notifier<Prefs> {
  @override
  Prefs build() {
    _load();
    return const Prefs();
  }

  Future<void> _load() async {
    final j = await ref.read(vaultProvider).read('prefs');
    if (j is Map) {
      state = Prefs(
        language: j['language'] as String? ?? 'system',
        themeMode: j['themeMode'] as String? ?? 'system',
      );
    }
  }

  void update(Prefs Function(Prefs) f) {
    state = f(state);
    ref.read(vaultProvider).write('prefs', {'language': state.language, 'themeMode': state.themeMode});
  }
}

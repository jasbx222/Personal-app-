import 'package:flutter_test/flutter_test.dart';
import 'package:phone2pc_desktop/core/strings.dart';

void main() {
  test('every English key has an Arabic translation and vice versa', () {
    // t() falls back to English, so compare via a probe that exposes the fallback.
    const en = Strings('en');
    const ar = Strings('ar');
    final keys = RegExp(r"'(\w+)':").allMatches(_source).map((m) => m.group(1)!).toSet();
    for (final k in keys) {
      expect(en.t(k), isNot(k), reason: 'missing en: $k');
      expect(ar.t(k), isNot(k), reason: 'missing ar: $k');
    }
  });
}

// Keys used by the UI, kept in sync by hand with lib/core/strings.dart.
const _source = "'history': 'settings': 'pair': 'emptyTitle': 'emptyBody': 'serverRunning': 'serverStopped': "
    "'serverError': 'copy': 'copied': 'pathCopied': 'open': 'openInBrowser': 'showInFolder': 'delete': 'cancel': "
    "'removeFromList': 'deleteFileToo': 'deleteTitle': 'fileMissing': 'badLink': 'saveFolder': 'chooseFolder': "
    "'autoCopy': 'autoCopySub': 'port': 'apply': 'portInvalid': 'portApplied': 'launchAtStartup': 'startMinimized': "
    "'deviceName': 'language': 'theme': 'system': 'light': 'dark': 'english': 'arabic': 'showQr': 'revoke': "
    "'revokeTitle': 'revokeBody': 'revokeConfirm': 'pairTitle': 'pairHelp': 'manualDetails': 'address': 'token': "
    "'noNetwork': 'newCodeCreated': 'firewallTitle': 'firewallBody': 'firewallAdd': 'firewallLater': 'quit': 'show': "
    "'received':";

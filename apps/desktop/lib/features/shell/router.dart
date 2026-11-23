import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../history/history_screen.dart';
import '../pairing/pairing_screen.dart';
import '../settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => HistoryScreen(highlightId: state.uri.queryParameters['item']),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/pair', builder: (_, _) => const PairingScreen()),
    ],
  );
});

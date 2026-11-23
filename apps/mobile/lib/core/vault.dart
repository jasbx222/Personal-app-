import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tiny JSON key/value store on top of the platform keystore (Keychain /
/// EncryptedSharedPreferences). Holds the pairing token, preferences and the
/// sent history, so no extra storage dependency is needed.
class Vault {
  Vault([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  Future<Object?> read(String key) async {
    try {
      final raw = await _s.read(key: key);
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null; // corrupted or unavailable: behave as if empty
    }
  }

  Future<void> write(String key, Object? value) async {
    try {
      await _s.write(key: key, value: jsonEncode(value));
    } catch (_) {}
  }

  Future<void> delete(String key) async {
    try {
      await _s.delete(key: key);
    } catch (_) {}
  }
}

import 'dart:convert';
import 'dart:math';

/// Generates a URL-safe random token (default 32 bytes = 256 bits).
String generateToken({int bytes = 32}) {
  final rnd = Random.secure();
  final data = List<int>.generate(bytes, (_) => rnd.nextInt(256));
  return base64UrlEncode(data).replaceAll('=', '');
}

/// Short random identifier for history items.
String generateId() {
  final rnd = Random.secure();
  final data = List<int>.generate(9, (_) => rnd.nextInt(256));
  return base64UrlEncode(data);
}

/// Compares two strings in time that does not depend on where they differ.
bool constantTimeEquals(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  var diff = x.length ^ y.length;
  final n = max(x.length, y.length);
  for (var i = 0; i < n; i++) {
    diff |= (i < x.length ? x[i] : 0) ^ (i < y.length ? y[i] : 0);
  }
  return diff == 0;
}

/// Extracts the token from an `Authorization: Bearer <token>` header value.
String? parseBearer(String? header) {
  if (header == null) return null;
  final m = RegExp(r'^\s*Bearer\s+(\S+)\s*$', caseSensitive: false).firstMatch(header);
  return m?.group(1);
}

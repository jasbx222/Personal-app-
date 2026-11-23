import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared/shared.dart';

/// A paired desktop.
class Pairing {
  const Pairing({required this.host, required this.port, required this.name, required this.token});

  final String host;
  final int port;
  final String name;
  final String token;

  Pairing copyWith({String? host, int? port, String? name}) =>
      Pairing(host: host ?? this.host, port: port ?? this.port, name: name ?? this.name, token: token);

  Map<String, Object?> toJson() => {'host': host, 'port': port, 'name': name, 'token': token};

  static Pairing? fromJson(Object? j) {
    if (j is! Map) return null;
    final host = j['host'], port = j['port'], name = j['name'], token = j['token'];
    if (host is! String || port is! int || name is! String || token is! String) return null;
    return Pairing(host: host, port: port, name: name, token: token);
  }
}

enum FailureKind { notPaired, unreachable, unauthorized, interrupted, cancelled, fileMissing, server }

class TransferFailure implements Exception {
  const TransferFailure(this.kind, [this.detail]);

  final FailureKind kind;
  final String? detail;

  @override
  String toString() => 'TransferFailure($kind, $detail)';
}

/// Lets the UI abort an in-flight request.
class CancelToken {
  bool cancelled = false;
  HttpClientRequest? _request;

  void cancel() {
    cancelled = true;
    _request?.abort();
  }
}

/// Talks to the desktop receiver using only `dart:io`.
class ApiClient {
  ApiClient(this.pairing);

  final Pairing pairing;

  Uri _uri(String path) => Uri(scheme: 'http', host: pairing.host, port: pairing.port, path: path);

  HttpClient _client() => HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 5);

  Future<HttpClientRequest> _open(HttpClient c, String method, String path) async {
    try {
      final req = await c.openUrl(method, _uri(path));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${pairing.token}');
      req.persistentConnection = false;
      return req;
    } on SocketException {
      throw const TransferFailure(FailureKind.unreachable);
    } on TimeoutException {
      throw const TransferFailure(FailureKind.unreachable);
    } on HttpException {
      throw const TransferFailure(FailureKind.unreachable);
    }
  }

  Future<String> _finish(HttpClientRequest req, CancelToken? cancel) async {
    try {
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      if (res.statusCode == 401) throw const TransferFailure(FailureKind.unauthorized);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw TransferFailure(FailureKind.server, _errorOf(body, res.statusCode));
      }
      return body;
    } on TransferFailure {
      rethrow;
    } catch (_) {
      if (cancel?.cancelled == true) throw const TransferFailure(FailureKind.cancelled);
      throw const TransferFailure(FailureKind.interrupted);
    }
  }

  String _errorOf(String body, int status) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] is String) return j['error'] as String;
    } catch (_) {}
    return 'HTTP $status';
  }

  /// Health check. Returns the desktop's device name.
  Future<PingResponse> ping({Duration timeout = const Duration(seconds: 4)}) async {
    final c = _client();
    try {
      final req = await _open(c, 'GET', ApiRoutes.ping).timeout(timeout, onTimeout: () {
        throw const TransferFailure(FailureKind.unreachable);
      });
      final body = await _finish(req, null).timeout(timeout, onTimeout: () {
        throw const TransferFailure(FailureKind.unreachable);
      });
      final p = PingResponse.tryParse(jsonDecode(body));
      if (p == null) throw const TransferFailure(FailureKind.server, 'not a Phone2PC device');
      return p;
    } finally {
      c.close(force: true);
    }
  }

  Future<void> sendText(String content, ItemKind type, {CancelToken? cancel}) async {
    final c = _client();
    try {
      final req = await _open(c, 'POST', ApiRoutes.text);
      cancel?._request = req;
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(TextRequest(content: content, type: type).toJson())));
      await _finish(req, cancel);
    } finally {
      c.close(force: true);
    }
  }

  /// Streams [path] as multipart/form-data without loading it into memory.
  Future<void> uploadFile(
    String path, {
    String? name,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    final file = File(path);
    final int total;
    try {
      total = await file.length();
    } on FileSystemException {
      throw const TransferFailure(FailureKind.fileMissing);
    }
    final fileName = (name ?? path.split(RegExp(r'[\\/]')).last).replaceAll(RegExp(r'[\r\n\x00]'), '_');
    final boundary = '----phone2pc${Random.secure().nextInt(1 << 32).toRadixString(16)}${DateTime.now().microsecondsSinceEpoch}';
    final escaped = fileName.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final head = utf8.encode('--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="$escaped"\r\n'
        'Content-Type: application/octet-stream\r\n\r\n');
    final tail = utf8.encode('\r\n--$boundary--\r\n');

    final c = _client();
    try {
      if (cancel?.cancelled == true) throw const TransferFailure(FailureKind.cancelled);
      final req = await _open(c, 'POST', ApiRoutes.file);
      cancel?._request = req;
      req.headers.contentType = ContentType('multipart', 'form-data', parameters: {'boundary': boundary});
      req.contentLength = head.length + total + tail.length; // known length: no chunked encoding
      var sent = 0;
      try {
        req.add(head);
        await req.addStream(file.openRead().map((chunk) {
          sent += chunk.length;
          onProgress?.call(sent, total);
          return chunk;
        }));
        req.add(tail);
      } catch (_) {
        if (cancel?.cancelled == true) throw const TransferFailure(FailureKind.cancelled);
        // The server may have answered early (e.g. 401) and closed the socket;
        // report that precisely if we can.
        throw const TransferFailure(FailureKind.interrupted);
      }
      await _finish(req, cancel);
      onProgress?.call(total, total);
    } finally {
      c.close(force: true);
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared/shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../core/paths.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Response _json(int status, Object body) => Response(status, body: jsonEncode(body), headers: _jsonHeaders);

/// The local HTTP receiver. Knows nothing about Flutter/Riverpod; the app
/// wires it up through the callbacks.
class TransferServer {
  TransferServer({
    required this.token,
    required this.saveDir,
    required this.deviceName,
    required this.recent,
    required this.onItem,
  });

  /// Evaluated per request so revoking a pairing takes effect immediately.
  final String Function() token;
  final String Function() saveDir;
  final String Function() deviceName;
  final List<HistoryItem> Function() recent;
  final FutureOr<void> Function(HistoryItem item) onItem;

  HttpServer? _http;

  int? get port => _http?.port;

  Future<void> start(int port) async {
    final router = Router()
      ..get(ApiRoutes.ping, _ping)
      ..post(ApiRoutes.text, _text)
      ..post(ApiRoutes.file, _file)
      ..get(ApiRoutes.history, _history);
    final handler = const Pipeline().addMiddleware(_auth).addHandler(router.call);
    // Bound to every IPv4 interface so the phone can reach it over the LAN.
    _http = await shelf_io.serve(handler, InternetAddress.anyIPv4, port, shared: false);
    _http!.idleTimeout = const Duration(minutes: 2);
  }

  Future<void> stop() async {
    final s = _http;
    _http = null;
    await s?.close(force: true);
  }

  Middleware get _auth => (inner) => (req) {
        final given = parseBearer(req.headers['authorization']);
        if (given == null || !constantTimeEquals(given, token())) {
          return _json(401, {'error': 'unauthorized'});
        }
        return inner(req);
      };

  Response _ping(Request req) => _json(200, PingResponse(deviceName: deviceName()).toJson());

  Response _history(Request req) {
    final limit = (int.tryParse(req.url.queryParameters['limit'] ?? '') ?? 50).clamp(1, 200);
    return _json(200, {
      'items': [for (final i in recent().take(limit)) i.toJson(includePath: false)],
    });
  }

  Future<Response> _text(Request req) async {
    final declared = req.contentLength;
    if (declared != null && declared > kMaxTextBytes + 1024) {
      return _json(413, {'error': 'too_large'});
    }
    final Map<String, dynamic> body;
    try {
      final bytes = await _readLimited(req.read(), kMaxTextBytes + 1024);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      body = decoded;
    } on _TooLarge {
      return _json(413, {'error': 'too_large'});
    } catch (_) {
      return _json(400, {'error': 'bad_json'});
    }
    final content = body['content'];
    if (content is! String || content.trim().isEmpty) {
      return _json(400, {'error': 'content_required'});
    }
    var kind = ItemKind.fromName(body['type'] as String?);
    if (!kind.isText) kind = ItemKind.text;
    if (kind == ItemKind.link && !isProbablyUrl(content)) kind = ItemKind.text;
    final item = HistoryItem(
      id: generateId(),
      kind: kind,
      text: content,
      size: utf8.encode(content).length,
      receivedAt: DateTime.now(),
    );
    await onItem(item);
    return _json(200, {'ok': true, 'id': item.id});
  }

  Future<Response> _file(Request req) async {
    final boundary = extractBoundary(req.headers['content-type']);
    if (boundary == null) return _json(400, {'error': 'multipart_required'});

    final saved = <HistoryItem>[];
    IOSink? sink;
    File? current;
    String? currentName;
    var written = 0;

    Future<void> discardCurrent() async {
      try {
        await sink?.close();
      } catch (_) {}
      sink = null;
      try {
        current?.deleteSync();
      } catch (_) {}
      current = null;
    }

    try {
      await parseMultipart(
        body: req.read(),
        boundary: boundary,
        onPartStart: (part) async {
          final raw = part.filename;
          if (raw == null) return; // ignore plain form fields
          final name = sanitizeFileName(raw);
          final now = DateTime.now();
          final dir = Directory(joinPath(saveDir(), dateFolderName(now)));
          await dir.create(recursive: true);
          current = reserveUniqueFile(dir, name);
          currentName = current!.uri.pathSegments.last;
          sink = current!.openWrite();
          written = 0;
        },
        onPartData: (data) async {
          final s = sink;
          if (s == null) return;
          s.add(data);
          written += data.length;
          await s.flush(); // back-pressure: don't read faster than the disk writes
        },
        onPartEnd: () async {
          final s = sink;
          final f = current;
          if (s == null || f == null) return;
          await s.close();
          sink = null;
          current = null;
          final item = HistoryItem(
            id: generateId(),
            kind: kindForFileName(currentName!),
            name: currentName,
            size: written,
            path: f.path,
            receivedAt: DateTime.now(),
          );
          saved.add(item);
          await onItem(item);
        },
      );
    } on FormatException {
      await discardCurrent();
      return _json(400, {'error': 'bad_multipart', 'saved': saved.length});
    } catch (e) {
      // Connection dropped mid-upload (or disk error): never keep a partial file.
      await discardCurrent();
      return _json(500, {'error': 'upload_failed', 'saved': saved.length});
    }

    if (saved.isEmpty) return _json(400, {'error': 'no_file'});
    return _json(200, {
      'ok': true,
      'items': [for (final i in saved) {'id': i.id, 'name': i.name, 'size': i.size}],
    });
  }
}

class _TooLarge implements Exception {}

Future<List<int>> _readLimited(Stream<List<int>> s, int limit) async {
  final out = BytesBuilder(copy: false);
  await for (final c in s) {
    out.add(c);
    if (out.length > limit) throw _TooLarge();
  }
  return out.takeBytes();
}

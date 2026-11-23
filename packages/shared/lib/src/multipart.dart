import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Headers of one multipart part.
class MultipartPart {
  MultipartPart(this.headers);

  /// Lower-cased header names.
  final Map<String, String> headers;

  String? get _disposition => headers['content-disposition'];

  String? get name => _param(_disposition, 'name');
  String? get filename => _param(_disposition, 'filename');
  String? get contentType => headers['content-type'];

  static String? _param(String? header, String key) {
    if (header == null) return null;
    final m = RegExp('(?:^|[;\\s])$key="((?:[^"\\\\]|\\\\.)*)"').firstMatch(header);
    if (m == null) return null;
    return m.group(1)!.replaceAllMapped(RegExp(r'\\(.)'), (x) => x.group(1)!);
  }
}

/// Extracts the boundary from a `multipart/form-data; boundary=...` header.
String? extractBoundary(String? contentType) {
  if (contentType == null) return null;
  if (!contentType.toLowerCase().startsWith('multipart/')) return null;
  final m = RegExp(r'boundary=(?:"([^"]+)"|([^;\s]+))', caseSensitive: false).firstMatch(contentType);
  return m?.group(1) ?? m?.group(2);
}

enum _State { data, afterDelimiter, headers, done }

/// Streaming multipart/form-data parser. Memory use is bounded by the chunk
/// size, so it is safe for multi-gigabyte uploads.
///
/// Callbacks are awaited, which gives the caller back-pressure (e.g. awaiting
/// a disk flush before the next chunk is read from the socket).
///
/// Throws [FormatException] for malformed or truncated bodies.
Future<void> parseMultipart({
  required Stream<List<int>> body,
  required String boundary,
  required FutureOr<void> Function(MultipartPart part) onPartStart,
  required FutureOr<void> Function(Uint8List data) onPartData,
  required FutureOr<void> Function() onPartEnd,
}) async {
  final delimiter = Uint8List.fromList(utf8.encode('\r\n--$boundary'));
  final headerEnd = Uint8List.fromList(const [13, 10, 13, 10]);
  // The body starts directly with "--boundary", so pretend a CRLF came first.
  var buf = Uint8List.fromList(const [13, 10]);
  var state = _State.data;
  var inPart = false;

  await for (final chunk in body) {
    if (state == _State.done) continue; // drain epilogue
    buf = _concat(buf, chunk);
    var again = true;
    while (again) {
      again = false;
      switch (state) {
        case _State.data:
          final i = _indexOf(buf, delimiter);
          if (i >= 0) {
            if (inPart) {
              if (i > 0) await onPartData(Uint8List.sublistView(buf, 0, i));
              await onPartEnd();
              inPart = false;
            }
            buf = Uint8List.sublistView(buf, i + delimiter.length);
            state = _State.afterDelimiter;
            again = true;
          } else {
            final keep = min(buf.length, delimiter.length - 1);
            final emit = buf.length - keep;
            if (emit > 0) {
              if (inPart) await onPartData(Uint8List.sublistView(buf, 0, emit));
              buf = Uint8List.sublistView(buf, emit);
            }
          }
        case _State.afterDelimiter:
          if (buf.length >= 2) {
            if (buf[0] == 45 && buf[1] == 45) {
              state = _State.done;
              buf = Uint8List(0);
            } else if (buf[0] == 13 && buf[1] == 10) {
              buf = Uint8List.sublistView(buf, 2);
              state = _State.headers;
              again = true;
            } else {
              throw const FormatException('Malformed multipart boundary line');
            }
          }
        case _State.headers:
          final i = _indexOf(buf, headerEnd);
          if (i >= 0) {
            final part = MultipartPart(_parseHeaders(utf8.decode(Uint8List.sublistView(buf, 0, i), allowMalformed: true)));
            buf = Uint8List.sublistView(buf, i + 4);
            await onPartStart(part);
            inPart = true;
            state = _State.data;
            again = true;
          } else if (buf.length > 16 * 1024) {
            throw const FormatException('Multipart headers too large');
          }
        case _State.done:
          break;
      }
    }
  }
  if (state != _State.done) {
    throw const FormatException('Unexpected end of multipart body');
  }
}

Map<String, String> _parseHeaders(String raw) {
  final out = <String, String>{};
  for (final line in raw.split('\r\n')) {
    final c = line.indexOf(':');
    if (c <= 0) continue;
    out[line.substring(0, c).trim().toLowerCase()] = line.substring(c + 1).trim();
  }
  return out;
}

Uint8List _concat(Uint8List a, List<int> b) {
  final bytes = b is Uint8List ? b : Uint8List.fromList(b);
  if (a.isEmpty) return bytes;
  final out = Uint8List(a.length + bytes.length);
  out.setRange(0, a.length, a);
  out.setRange(a.length, out.length, bytes);
  return out;
}

int _indexOf(Uint8List hay, Uint8List needle) {
  final n = needle.length;
  final last = hay.length - n;
  final first = needle[0];
  for (var i = 0; i <= last; i++) {
    if (hay[i] != first) continue;
    var j = 1;
    while (j < n && hay[i + j] == needle[j]) {
      j++;
    }
    if (j == n) return i;
  }
  return -1;
}

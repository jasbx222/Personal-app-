import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone2pc_desktop/features/server/transfer_server.dart';
import 'package:shared/shared.dart';

void main() {
  late Directory tmp;
  late TransferServer server;
  late int port;
  final received = <HistoryItem>[];
  const token = 'secret-token';

  setUp(() async {
    HttpOverrides.global = null; // flutter_test blocks real sockets by default
    received.clear();
    tmp = Directory.systemTemp.createTempSync('p2p_srv');
    server = TransferServer(
      token: () => token,
      saveDir: () => tmp.path,
      deviceName: () => 'Test PC',
      recent: () => received,
      onItem: received.add,
    );
    await server.start(0);
    port = server.port!;
  });

  tearDown(() async {
    await server.stop();
    tmp.deleteSync(recursive: true);
  });

  Future<(int, String)> call(String method, String path,
      {String? auth = 'Bearer $token', Object? json, List<int>? raw, String? contentType}) async {
    final c = HttpClient();
    final r = await c.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
    if (auth != null) r.headers.set('authorization', auth);
    if (json != null) {
      r.headers.contentType = ContentType.json;
      r.add(utf8.encode(jsonEncode(json)));
    }
    if (raw != null) {
      r.headers.set('content-type', contentType!);
      r.add(raw);
    }
    final res = await r.close();
    final body = await utf8.decodeStream(res);
    c.close();
    return (res.statusCode, body);
  }

  test('rejects missing or wrong token', () async {
    expect((await call('GET', '/ping', auth: null)).$1, 401);
    expect((await call('GET', '/ping', auth: 'Bearer nope')).$1, 401);
    expect((await call('POST', '/text', auth: 'Bearer nope', json: {'content': 'x', 'type': 'text'})).$1, 401);
    final ok = await call('GET', '/ping');
    expect(ok.$1, 200);
    expect(jsonDecode(ok.$2)['deviceName'], 'Test PC');
  });

  test('stores text and links', () async {
    expect((await call('POST', '/text', json: {'content': 'مرحبا', 'type': 'text'})).$1, 200);
    expect((await call('POST', '/text', json: {'content': 'https://example.com', 'type': 'link'})).$1, 200);
    expect((await call('POST', '/text', json: {'content': 'not a url', 'type': 'link'})).$1, 200);
    expect((await call('POST', '/text', json: {'content': '  '})).$1, 400);
    expect(received.map((e) => e.kind), [ItemKind.text, ItemKind.link, ItemKind.text]);
    final h = jsonDecode((await call('GET', '/history')).$2)['items'] as List;
    expect(h.length, 3);
    expect(h.first.containsKey('path'), isFalse);
  });

  test('streams multipart files, sanitizes names, de-duplicates', () async {
    const b = 'XBOUNDARYX';
    List<int> body(String filename, List<int> data) => [
          ...utf8.encode('--$b\r\nContent-Disposition: form-data; name="file"; filename="$filename"\r\n'
              'Content-Type: application/octet-stream\r\n\r\n'),
          ...data,
          ...utf8.encode('\r\n--$b--\r\n'),
        ];
    final data = List<int>.generate(300000, (i) => i % 251);
    const ct = 'multipart/form-data; boundary=$b';

    final r1 = await call('POST', '/file', raw: body('pic.png', data), contentType: ct);
    final r2 = await call('POST', '/file', raw: body('pic.png', data), contentType: ct);
    final r3 = await call('POST', '/file', raw: body('../../evil.txt', [1, 2, 3]), contentType: ct);
    expect([r1.$1, r2.$1, r3.$1], [200, 200, 200]);

    expect(received.length, 3);
    expect(received[0].kind, ItemKind.image);
    expect(File(received[0].path!).readAsBytesSync(), data);
    expect(received[1].name, 'pic (1).png');
    expect(received[2].name, 'evil.txt');
    for (final i in received) {
      expect(i.path!.startsWith(tmp.path), isTrue); // nothing escaped the save dir
      expect(i.path!.contains('${Platform.pathSeparator}${dateFolderName(DateTime.now())}${Platform.pathSeparator}'), isTrue);
    }
  });

  test('truncated upload leaves no partial file', () async {
    const b = 'XBOUNDARYX';
    final partial = [
      ...utf8.encode('--$b\r\nContent-Disposition: form-data; name="file"; filename="big.bin"\r\n\r\n'),
      ...List<int>.filled(1000, 7), // no closing boundary
    ];
    final r = await call('POST', '/file', raw: partial, contentType: 'multipart/form-data; boundary=$b');
    expect(r.$1, 400);
    expect(received, isEmpty);
    final files = tmp.listSync(recursive: true).whereType<File>();
    expect(files, isEmpty);
  });
}

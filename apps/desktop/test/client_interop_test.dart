// Runs the real mobile ApiClient against the real desktop TransferServer.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone2pc_desktop/features/server/transfer_server.dart';
import 'package:shared/shared.dart';

import '../../mobile/lib/features/connection/api_client.dart';

void main() {
  late Directory tmp;
  late TransferServer server;
  final received = <HistoryItem>[];
  const token = 'tok-123';

  setUp(() async {
    HttpOverrides.global = null;
    received.clear();
    tmp = Directory.systemTemp.createTempSync('p2p_interop');
    server = TransferServer(
      token: () => token,
      saveDir: () => tmp.path,
      deviceName: () => 'Interop PC',
      recent: () => received,
      onItem: received.add,
    );
    await server.start(0);
  });

  tearDown(() async {
    await server.stop();
    tmp.deleteSync(recursive: true);
  });

  Pairing pairing({String tok = token, int? port}) =>
      Pairing(host: '127.0.0.1', port: port ?? server.port!, name: 'x', token: tok);

  test('ping, text, and a 20 MB upload with progress', () async {
    final c = ApiClient(pairing());
    expect((await c.ping()).deviceName, 'Interop PC');
    await c.sendText('hello', ItemKind.text);
    expect(received.single.text, 'hello');

    final src = File('${tmp.path}${Platform.pathSeparator}src.bin');
    final rnd = Random(1);
    final sink = src.openWrite();
    for (var i = 0; i < 20; i++) {
      sink.add(List<int>.generate(1024 * 1024, (_) => rnd.nextInt(256)));
    }
    await sink.close();

    var last = 0;
    await c.uploadFile(src.path, name: 'ملف "quoted".bin', onProgress: (s, t) => last = s);
    expect(last, 20 * 1024 * 1024);
    final item = received.last;
    expect(item.name, 'ملف _quoted_.bin');
    expect(item.size, 20 * 1024 * 1024);
    expect(File(item.path!).readAsBytesSync(), src.readAsBytesSync());
  });

  test('wrong token is unauthorized', () async {
    final c = ApiClient(pairing(tok: 'bad'));
    await expectLater(c.ping(), throwsA(isA<TransferFailure>().having((e) => e.kind, 'kind', FailureKind.unauthorized)));
    await expectLater(c.sendText('x', ItemKind.text), throwsA(isA<TransferFailure>().having((e) => e.kind, 'kind', FailureKind.unauthorized)));
  });

  test('unreachable host', () async {
    final c = ApiClient(pairing(port: 1));
    await expectLater(c.ping(), throwsA(isA<TransferFailure>().having((e) => e.kind, 'kind', FailureKind.unreachable)));
  });

  test('cancel mid-upload leaves nothing behind', () async {
    final src = File('${tmp.path}${Platform.pathSeparator}big.bin')..writeAsBytesSync(List<int>.filled(60 * 1024 * 1024, 1));
    final token = CancelToken();
    final c = ApiClient(pairing());
    final f = c.uploadFile(src.path, cancel: token, onProgress: (s, t) {
      if (s > 2 * 1024 * 1024) token.cancel();
    });
    await expectLater(f, throwsA(isA<TransferFailure>().having((e) => e.kind, 'kind', FailureKind.cancelled)));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(received, isEmpty);
    final leftovers = tmp.listSync(recursive: true).whereType<File>().where((f) => !f.path.endsWith('big.bin'));
    expect(leftovers, isEmpty);
  });

  test('missing file', () async {
    await expectLater(ApiClient(pairing()).uploadFile('/nope/nothing.bin'),
        throwsA(isA<TransferFailure>().having((e) => e.kind, 'kind', FailureKind.fileMissing)));
  });
}

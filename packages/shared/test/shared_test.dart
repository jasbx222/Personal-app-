import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeFileName', () {
    test('blocks traversal and illegal chars', () {
      expect(sanitizeFileName('../../etc/passwd'), 'passwd');
      expect(sanitizeFileName(r'C:\Windows\evil.exe'), 'evil.exe');
      expect(sanitizeFileName('a<b>:c|d?.txt'), 'a_b__c_d_.txt');
      expect(sanitizeFileName('..'), 'file');
      expect(sanitizeFileName(''), 'file');
      expect(sanitizeFileName('CON.txt'), '_CON.txt');
      expect(sanitizeFileName('.bashrc'), '_bashrc');
      expect(sanitizeFileName('photo.jpg. '), 'photo.jpg');
    });
    test('truncates long names keeping extension', () {
      final n = sanitizeFileName('${'a' * 300}.mp4');
      expect(n.length, 120);
      expect(n.endsWith('.mp4'), isTrue);
    });
  });

  test('reserveUniqueFile appends numbers', () {
    final d = Directory.systemTemp.createTempSync('p2p');
    addTearDown(() => d.deleteSync(recursive: true));
    expect(reserveUniqueFile(d, 'a.txt').path.endsWith('a.txt'), isTrue);
    expect(reserveUniqueFile(d, 'a.txt').path.endsWith('a (1).txt'), isTrue);
    expect(reserveUniqueFile(d, 'a.txt').path.endsWith('a (2).txt'), isTrue);
  });

  test('tokens and bearer', () {
    final t = generateToken();
    expect(t.length, greaterThanOrEqualTo(43));
    expect(constantTimeEquals(t, t), isTrue);
    expect(constantTimeEquals(t, '${t}x'), isFalse);
    expect(parseBearer('Bearer abc'), 'abc');
    expect(parseBearer('Basic abc'), isNull);
    expect(parseBearer(null), isNull);
  });

  test('pairing payload round trip', () {
    const p = PairingPayload(ip: '192.168.1.5', port: 53317, deviceName: 'PC', token: 'tok');
    final back = PairingPayload.tryDecode(p.encode())!;
    expect(back.ip, p.ip);
    expect(back.token, 'tok');
    expect(PairingPayload.tryDecode('nope'), isNull);
  });

  test('isProbablyUrl', () {
    expect(isProbablyUrl('https://example.com/a?b=1'), isTrue);
    expect(isProbablyUrl('example.com'), isFalse);
    expect(isProbablyUrl('see https://example.com'), isFalse);
    expect(isProbablyUrl('javascript:alert(1)'), isFalse);
  });

  group('multipart', () {
    const boundary = '----p2pTESTboundary';
    final payload = Uint8List.fromList(List<int>.generate(5000, (i) => i % 256)
      ..addAll(utf8.encode('\r\n--${boundary.substring(0, 9)} near miss\r\n--')));
    final body = <int>[
      ...utf8.encode('--$boundary\r\nContent-Disposition: form-data; name="note"\r\n\r\nhello'),
      ...utf8.encode('\r\n--$boundary\r\nContent-Disposition: form-data; name="file"; filename="we\\"ird ملف.bin"\r\n'
          'Content-Type: application/octet-stream\r\n\r\n'),
      ...payload,
      ...utf8.encode('\r\n--$boundary--\r\n'),
    ];

    for (final size in [1, 2, 7, 64, 1000, body.length]) {
      test('parses with chunk size $size', () async {
        final parts = <MultipartPart>[];
        final data = <BytesBuilder>[];
        Stream<List<int>> chunks() async* {
          for (var i = 0; i < body.length; i += size) {
            yield body.sublist(i, i + size > body.length ? body.length : i + size);
          }
        }

        await parseMultipart(
          body: chunks(),
          boundary: boundary,
          onPartStart: (p) {
            parts.add(p);
            data.add(BytesBuilder());
          },
          onPartData: (d) => data.last.add(d),
          onPartEnd: () {},
        );
        expect(parts.length, 2);
        expect(parts[0].name, 'note');
        expect(parts[0].filename, isNull);
        expect(utf8.decode(data[0].toBytes()), 'hello');
        expect(parts[1].filename, 'we"ird ملف.bin');
        expect(data[1].toBytes(), payload);
      });
    }

    test('truncated body throws', () {
      expect(
        parseMultipart(
          body: Stream.value(body.sublist(0, body.length - 20)),
          boundary: boundary,
          onPartStart: (_) {},
          onPartData: (_) {},
          onPartEnd: () {},
        ),
        throwsFormatException,
      );
    });

    test('extractBoundary', () {
      expect(extractBoundary('multipart/form-data; boundary=abc'), 'abc');
      expect(extractBoundary('multipart/form-data; boundary="a b"'), 'a b');
      expect(extractBoundary('application/json'), isNull);
    });
  });
}

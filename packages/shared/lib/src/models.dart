import 'dart:convert';

import 'constants.dart';

enum ItemKind {
  text,
  link,
  image,
  video,
  file;

  static ItemKind fromName(String? name) =>
      ItemKind.values.firstWhere((k) => k.name == name, orElse: () => ItemKind.file);

  bool get isText => this == text || this == link;
}

/// Content of the pairing QR code.
class PairingPayload {
  const PairingPayload({
    required this.ip,
    required this.port,
    required this.deviceName,
    required this.token,
  });

  final String ip;
  final int port;
  final String deviceName;
  final String token;

  Map<String, Object?> toJson() => {
        'ip': ip,
        'port': port,
        'deviceName': deviceName,
        'pairingToken': token,
      };

  String encode() => jsonEncode(toJson());

  static PairingPayload? tryDecode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final ip = j['ip'];
      final port = j['port'];
      final name = j['deviceName'];
      final token = j['pairingToken'];
      if (ip is! String || port is! int || name is! String || token is! String) {
        return null;
      }
      if (ip.isEmpty || token.isEmpty || port < 1 || port > 65535) return null;
      return PairingPayload(ip: ip, port: port, deviceName: name, token: token);
    } catch (_) {
      return null;
    }
  }
}

/// Response of `GET /ping`.
class PingResponse {
  const PingResponse({required this.deviceName, this.app = kAppId, this.version = kApiVersion});

  final String app;
  final String deviceName;
  final String version;

  Map<String, Object?> toJson() => {'app': app, 'deviceName': deviceName, 'version': version};

  static PingResponse? tryParse(Object? j) {
    if (j is! Map || j['app'] != kAppId || j['deviceName'] is! String) return null;
    return PingResponse(deviceName: j['deviceName'] as String, version: '${j['version'] ?? ''}');
  }
}

/// Body of `POST /text`.
class TextRequest {
  const TextRequest({required this.content, required this.type});

  final String content;
  final ItemKind type; // text | link

  Map<String, Object?> toJson() => {'content': content, 'type': type.name};
}

/// An item received by the desktop (also the shape returned by `GET /history`).
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.kind,
    required this.receivedAt,
    this.text,
    this.name,
    this.size = 0,
    this.path,
  });

  final String id;
  final ItemKind kind;
  final DateTime receivedAt;

  /// Content for text / link items.
  final String? text;

  /// File name for file items.
  final String? name;
  final int size;

  /// Absolute path on the desktop (never sent to the phone).
  final String? path;

  Map<String, Object?> toJson({bool includePath = true}) => {
        'id': id,
        'kind': kind.name,
        'receivedAt': receivedAt.toUtc().toIso8601String(),
        if (text != null) 'text': text,
        if (name != null) 'name': name,
        'size': size,
        if (includePath && path != null) 'path': path,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: j['id'] as String,
        kind: ItemKind.fromName(j['kind'] as String?),
        receivedAt: DateTime.parse(j['receivedAt'] as String).toLocal(),
        text: j['text'] as String?,
        name: j['name'] as String?,
        size: (j['size'] as num?)?.toInt() ?? 0,
        path: j['path'] as String?,
      );
}

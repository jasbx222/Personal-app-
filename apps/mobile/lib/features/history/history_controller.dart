import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../connection/prefs.dart';

class SentEntry {
  const SentEntry({required this.id, required this.kind, required this.label, required this.size, required this.sentAt});

  final String id;
  final ItemKind kind;
  final String label;
  final int size;
  final DateTime sentAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'label': label,
        'size': size,
        'sentAt': sentAt.toUtc().toIso8601String(),
      };

  static SentEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return SentEntry(
        id: j['id'] as String,
        kind: ItemKind.fromName(j['kind'] as String?),
        label: j['label'] as String,
        size: (j['size'] as num).toInt(),
        sentAt: DateTime.parse(j['sentAt'] as String).toLocal(),
      );
    } catch (_) {
      return null;
    }
  }
}

final historyProvider = NotifierProvider<HistoryController, List<SentEntry>>(HistoryController.new);

/// Local "sent" history, newest first, capped at 200 and kept in the keystore.
class HistoryController extends Notifier<List<SentEntry>> {
  static const _key = 'sent_history';
  static const _max = 200;

  @override
  List<SentEntry> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final j = await ref.read(vaultProvider).read(_key);
    if (j is List) {
      state = [for (final e in j) ?SentEntry.fromJson(e), ...state];
    }
  }

  void add({required ItemKind kind, required String label, required int size}) {
    final e = SentEntry(id: generateId(), kind: kind, label: label, size: size, sentAt: DateTime.now());
    state = [e, ...state].take(_max).toList();
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }

  void _persist() => ref.read(vaultProvider).write(_key, [for (final e in state) e.toJson()]);
}

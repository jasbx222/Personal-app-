import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../core/paths.dart';

class HistoryStore {
  HistoryStore(Directory dir) : _file = File(joinPath(dir.path, 'history.json'));

  final File _file;

  List<HistoryItem> load() {
    try {
      final j = jsonDecode(_file.readAsStringSync());
      if (j is List) {
        return [for (final e in j) HistoryItem.fromJson(e as Map<String, dynamic>)];
      }
    } catch (_) {}
    return [];
  }

  void save(List<HistoryItem> items) {
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(jsonEncode([for (final i in items) i.toJson()]), flush: true);
    tmp.renameSync(_file.path);
  }
}

final historyStoreProvider = Provider<HistoryStore>((_) => throw UnimplementedError());

final historyProvider = NotifierProvider<HistoryController, List<HistoryItem>>(HistoryController.new);

/// Newest first, capped at [maxItems].
class HistoryController extends Notifier<List<HistoryItem>> {
  static const maxItems = 500;

  @override
  List<HistoryItem> build() => ref.read(historyStoreProvider).load();

  void add(HistoryItem item) {
    final next = [item, ...state];
    state = next.length > maxItems ? next.sublist(0, maxItems) : next;
    ref.read(historyStoreProvider).save(state);
  }

  void remove(String id) {
    state = [for (final i in state) if (i.id != id) i];
    ref.read(historyStoreProvider).save(state);
  }
}

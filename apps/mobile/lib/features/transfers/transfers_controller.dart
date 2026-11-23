import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../connection/api_client.dart';
import '../connection/connection_controller.dart';
import '../history/history_controller.dart';

enum TaskStatus { queued, uploading, done, failed, cancelled }

class TransferTask {
  TransferTask({
    required this.id,
    required this.kind,
    required this.label,
    this.path,
    this.text,
    this.total = 0,
  });

  final String id;
  final ItemKind kind;
  final String label; // file name or text preview
  final String? path; // for files
  final String? text; // for text/links
  int total;
  int sent = 0;
  TaskStatus status = TaskStatus.queued;
  FailureKind? failure;
  String? detail;
  CancelToken? cancel;

  double? get progress => total > 0 && status == TaskStatus.uploading ? (sent / total).clamp(0.0, 1.0) : null;
}

final transfersProvider = NotifierProvider<TransfersController, List<TransferTask>>(TransfersController.new);

/// In-memory upload queue (max [_parallel] at a time) with cancel and retry.
class TransfersController extends Notifier<List<TransferTask>> {
  static const _parallel = 2;

  @override
  List<TransferTask> build() => const [];

  void _touch() => state = List.of(state); // notify: tasks are mutated in place

  void sendText(String content, {ItemKind? type}) {
    final text = content.trim();
    if (text.isEmpty) return;
    final kind = type ?? (isProbablyUrl(text) ? ItemKind.link : ItemKind.text);
    _add(TransferTask(
      id: generateId(),
      kind: kind,
      label: text.length > 120 ? '${text.substring(0, 120)}…' : text,
      text: text,
      total: text.length,
    ));
  }

  void sendFiles(Iterable<String> paths) {
    for (final p in paths) {
      final name = p.split(RegExp(r'[\\/]')).last;
      _add(TransferTask(id: generateId(), kind: kindForFileName(name), label: name, path: p));
    }
  }

  void _add(TransferTask t) {
    state = [t, ...state];
    _pump();
  }

  void cancel(String id) {
    final t = _find(id);
    if (t == null) return;
    if (t.status == TaskStatus.uploading) {
      t.cancel?.cancel();
    } else if (t.status == TaskStatus.queued) {
      t.status = TaskStatus.cancelled;
      _touch();
    }
  }

  void retry(String id) {
    final t = _find(id);
    if (t == null || (t.status != TaskStatus.failed && t.status != TaskStatus.cancelled)) return;
    t.status = TaskStatus.queued;
    t.sent = 0;
    t.failure = null;
    t.detail = null;
    _touch();
    _pump();
  }

  void remove(String id) {
    _find(id)?.cancel?.cancel();
    state = [for (final t in state) if (t.id != id) t];
  }

  void clearFinished() {
    state = [
      for (final t in state)
        if (t.status == TaskStatus.queued || t.status == TaskStatus.uploading) t,
    ];
  }

  TransferTask? _find(String id) => state.where((t) => t.id == id).firstOrNull;

  void _pump() {
    // Oldest queued first.
    for (final t in state.reversed) {
      final active = state.where((x) => x.status == TaskStatus.uploading).length;
      if (active >= _parallel) return;
      if (t.status == TaskStatus.queued) {
        t.status = TaskStatus.uploading;
        _touch();
        unawaited(_run(t));
      }
    }
  }

  Future<void> _run(TransferTask t) async {
    final conn = ref.read(connectionProvider.notifier);
    final client = conn.client;
    final token = CancelToken();
    t.cancel = token;
    try {
      if (client == null) throw const TransferFailure(FailureKind.notPaired);
      if (t.text != null) {
        await client.sendText(t.text!, t.kind, cancel: token);
      } else {
        var last = 0;
        await client.uploadFile(
          t.path!,
          name: t.label,
          cancel: token,
          onProgress: (sent, total) {
            t.sent = sent;
            t.total = total;
            // Repaint at most ~10×/s.
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - last > 100 || sent == total) {
              last = now;
              _touch();
            }
          },
        );
      }
      t.status = TaskStatus.done;
      t.sent = t.total;
      ref.read(historyProvider.notifier).add(
            kind: t.kind,
            label: t.label,
            size: t.text != null ? t.text!.length : t.total,
          );
    } on TransferFailure catch (e) {
      var kind = e.kind;
      t.detail = e.detail;
      if (kind == FailureKind.cancelled) {
        t.status = TaskStatus.cancelled;
      } else {
        t.status = TaskStatus.failed;
        if (kind == FailureKind.interrupted || kind == FailureKind.unreachable) {
          // An early 401 shows up as a broken pipe; a ping tells which it was.
          await conn.check();
          if (ref.read(connectionProvider).status == LinkStatus.tokenInvalid) kind = FailureKind.unauthorized;
        } else {
          conn.reportFailure(kind);
        }
        t.failure = kind;
      }
    } catch (_) {
      t.status = TaskStatus.failed;
      t.failure = FailureKind.interrupted;
    } finally {
      t.cancel = null;
      _touch();
      _pump();
    }
  }
}

import 'dart:io';

import 'models.dart';

final _reservedWindows = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$', caseSensitive: false);

/// Turns an untrusted file name into a safe single path segment.
///
/// * keeps only the last path component (defeats `../` and absolute paths)
/// * strips control characters and characters illegal on Windows
/// * avoids hidden/dot-only names and reserved Windows device names
/// * limits the length while keeping the extension
String sanitizeFileName(String raw, {int maxLength = 120}) {
  var name = raw.split(RegExp(r'[\\/]')).last;
  name = name.replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"|?*]'), '_');
  name = name.trim().replaceAll(RegExp(r'[. ]+$'), '');
  name = name.replaceFirst(RegExp(r'^\.+'), '_');
  if (name.isEmpty) name = 'file';

  var dot = name.lastIndexOf('.');
  var base = dot > 0 ? name.substring(0, dot) : name;
  var ext = dot > 0 ? name.substring(dot) : '';
  if (_reservedWindows.hasMatch(base)) base = '_$base';
  if (ext.length > 16) ext = ext.substring(0, 16);
  final room = maxLength - ext.length;
  if (base.length > room) base = base.substring(0, room < 1 ? 1 : room);
  return '$base$ext';
}

/// Atomically creates an empty file named [name] inside [dir], appending
/// ` (1)`, ` (2)`, … when the name is already taken. [name] must already be
/// sanitized.
File reserveUniqueFile(Directory dir, String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  for (var i = 0; i < 100000; i++) {
    final candidate = File('${dir.path}${Platform.pathSeparator}${i == 0 ? name : '$base ($i)$ext'}');
    try {
      candidate.createSync(exclusive: true);
      return candidate;
    } on FileSystemException {
      if (!candidate.existsSync()) rethrow; // a real error, not a name clash
    }
  }
  throw const FileSystemException('Could not find a free file name');
}

const _imageExt = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'tif', 'tiff', 'svg'};
const _videoExt = {'mp4', 'mov', 'm4v', 'mkv', 'avi', 'webm', '3gp', 'wmv', 'mpg', 'mpeg'};

ItemKind kindForFileName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return ItemKind.file;
  final ext = name.substring(dot + 1).toLowerCase();
  if (_imageExt.contains(ext)) return ItemKind.image;
  if (_videoExt.contains(ext)) return ItemKind.video;
  return ItemKind.file;
}

/// `yyyy-MM-dd`, used for the per-day folders.
String dateFolderName(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// Human readable size, e.g. `1.4 MB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/app_paths.dart';

class LibraryEntry {
  LibraryEntry({required this.id, required this.name, required this.path, required this.format,
      required this.pages, required this.bytes, required this.createdAt, this.thumb});
  final String id;
  String name, path;
  final String format;
  final int pages, bytes;
  final DateTime createdAt;
  final String? thumb;

  Map<String, Object?> toJson() => {
        'id': id, 'name': name, 'path': path, 'format': format, 'pages': pages,
        'bytes': bytes, 'createdAt': createdAt.toIso8601String(), 'thumb': thumb,
      };
  static LibraryEntry fromJson(Map m) => LibraryEntry(
        id: m['id'] as String,
        name: m['name'] as String,
        path: m['path'] as String,
        format: m['format'] as String,
        pages: (m['pages'] as num).toInt(),
        bytes: (m['bytes'] as num).toInt(),
        createdAt: DateTime.parse(m['createdAt'] as String),
        thumb: m['thumb'] as String?,
      );
}

/// فهرست اسناد ذخیره‌شده (فقط فرادادهٔ فایل‌ها؛ خود فایل‌ها در مسیر انتخاب کاربر هستند).
class DocumentLibrary extends ChangeNotifier {
  List<LibraryEntry> entries = [];

  static File get _file => File('${appDataDir().path}${Platform.pathSeparator}library.json');
  static Directory get thumbsDir {
    final d = Directory('${appDataDir().path}${Platform.pathSeparator}thumbs');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<DocumentLibrary> load() async {
    final l = DocumentLibrary();
    try {
      if (await _file.exists()) {
        final list = jsonDecode(await _file.readAsString()) as List;
        l.entries = [for (final e in list) LibraryEntry.fromJson(e as Map)];
      }
    } catch (_) {}
    return l;
  }

  Future<void> _save() async {
    try {
      await _file.writeAsString(jsonEncode([for (final e in entries) e.toJson()]), flush: true);
    } catch (_) {}
  }

  void add(LibraryEntry e) {
    entries.insert(0, e);
    notifyListeners();
    _save();
  }

  void remove(String id) {
    final i = entries.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final t = entries[i].thumb;
    if (t != null) {
      try {
        File(t).deleteSync();
      } catch (_) {}
    }
    entries.removeAt(i);
    notifyListeners();
    _save();
  }

  void touch() {
    notifyListeners();
    _save();
  }
}

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Thumbnail & pratinjau memakai Quick Look bawaan macOS (qlmanage),
/// jadi HEIC dari iPhone bisa tampil dan orientasinya benar.
class ThumbService {
  ThumbService(String cacheRoot) : _dir = Directory(p.join(cacheRoot, 'thumbs'));

  final Directory _dir;
  final Map<String, Future<File?>> _cache = {};
  final Queue<Completer<void>> _waiting = Queue();
  int _active = 0;
  static const _maxActive = 4;

  static const _native = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};

  static bool isNative(String path) => _native.contains(p.extension(path).toLowerCase());

  Future<File?> PhotoThumb(String path) => _get(path, 400);

  /// Gambar besar untuk penampil. Format yang dibaca Flutter langsung pakai file asli.
  Future<File?> preview(String path) =>
      isNative(path) ? Future.value(File(path)) : _get(path, 2400);

  Future<File?> _get(String path, int size) =>
      _cache.putIfAbsent('$size|$path', () => _make(path, size));

  Future<void> _acquire() async {
    if (_active < _maxActive) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
  }

  Future<File?> _make(String path, int size) async {
    final name = '${md5.convert(utf8.encode(path))}_$size.png';
    final out = File(p.join(_dir.path, name));
    if (await out.exists()) return out;

    await _acquire();
    Directory? tmp;
    try {
      await _dir.create(recursive: true);
      tmp = await Directory.systemTemp.createTemp('kenang_ql');
      final r = await Process.run(
        '/usr/bin/qlmanage',
        ['-t', '-s', '$size', '-o', tmp.path, path],
      );
      if (r.exitCode != 0) return null;
      final pngs = tmp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .toList();
      if (pngs.isEmpty) return null;
      try {
        await pngs.first.rename(out.path);
      } on FileSystemException {
        await pngs.first.copy(out.path);
      }
      return out;
    } catch (_) {
      return null;
    } finally {
      _release();
      if (tmp != null) {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}

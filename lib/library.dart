import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'services/exiftool.dart';
import 'services/index_store.dart';
import 'services/meta_codec.dart';

enum SourceKind { all, folder, album, noMemory, noLocation }

@immutable
class Source {
  const Source(this.kind, [this.key]);
  final SourceKind kind;

  /// Path folder, atau nama album.
  final String? key;

  @override
  bool operator ==(Object other) => other is Source && other.kind == kind && other.key == key;
  @override
  int get hashCode => Object.hash(kind, key);
}

class _Undo {
  _Undo(this.label, this.before);
  final String label;
  final Map<String, PhotoMeta> before;
}

const kAlbumFile = 'koleksi.kenang.json';

/// Seluruh isi pustaka foto + pilihan + penulisan info.
class Library extends ChangeNotifier {
  Library({required this.supportDir});

  final String supportDir;
  ExifTool? exif;

  String? root;
  final Map<String, PhotoItem> _items = {};
  List<PhotoItem> _sorted = [];
  List<AlbumDef> albums = [];

  Source source = const Source(SourceKind.all);
  String query = '';
  final Set<String> selected = {};
  String? focused;
  String? _anchor;
  bool viewerOpen = false;

  bool scanning = false;
  bool busy = false;
  double? progress;
  String? status;
  String? error;

  _Undo? _undo;
  Timer? _slideTimer;

  List<PhotoItem>? _visible;
  List<String> folders = [];
  Map<String, int> _folderCounts = {};
  Map<String, int> _tagCounts = {};
  List<String> allTags = [];
  int noMemoryCount = 0;
  int noLocationCount = 0;

  int get totalCount => _sorted.length;
  bool get canUndo => _undo != null && !busy;
  String? get undoLabel => _undo?.label;
  bool get slideshow => _slideTimer != null;

  PhotoItem? get focusedItem => focused == null ? null : _items[focused];

  List<PhotoItem> get selectedItems =>
      _sorted.where((i) => selected.contains(i.path)).toList();

  List<PhotoItem> get visible => _visible ??= _computeVisible();

  int folderCount(String f) => _folderCounts[f] ?? 0;
  int tagCount(String tag) => _tagCounts[tag.trim().toLowerCase()] ?? 0;

  String folderLabel(String folder) {
    final r = root;
    if (r == null) return folder;
    final rel = p.relative(folder, from: r);
    if (rel == '.') return '(folder utama)';
    return p.split(rel).join(' / ');
  }

  String get sourceTitle {
    final r = root == null ? '' : p.basename(root!);
    final s = switch (source.kind) {
      SourceKind.all => 'Semua foto',
      SourceKind.folder => folderLabel(source.key ?? ''),
      SourceKind.album => 'Album: ${source.key}',
      SourceKind.noMemory => 'Belum ada memori',
      SourceKind.noLocation => 'Tanpa lokasi',
    };
    return r.isEmpty ? s : '$r  /  $s';
  }

  void _changed() {
    _visible = null;
    notifyListeners();
  }

  List<PhotoItem> _computeVisible() {
    Iterable<PhotoItem> it = _sorted;
    switch (source.kind) {
      case SourceKind.all:
        break;
      case SourceKind.folder:
        it = it.where((i) => i.folder == source.key);
      case SourceKind.album:
        final album = albums.where((a) => a.name == source.key).firstOrNull;
        final tag = (album?.tag ?? '').trim().toLowerCase();
        it = it.where((i) => i.meta.tags.any((t) => t.toLowerCase() == tag));
      case SourceKind.noMemory:
        it = it.where((i) => !i.meta.hasMemory);
      case SourceKind.noLocation:
        it = it.where((i) => !i.meta.hasLocation);
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      it = it.where((i) {
        final m = i.meta;
        return m.title.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q) ||
            m.locationName.toLowerCase().contains(q) ||
            m.tags.any((t) => t.toLowerCase().contains(q)) ||
            i.fileName.toLowerCase().contains(q);
      });
    }
    return it.toList();
  }

  void _rebuildDerived() {
    final fc = <String, int>{};
    final tc = <String, int>{};
    final tagNames = <String, String>{};
    var nm = 0, nl = 0;
    for (final i in _sorted) {
      fc[i.folder] = (fc[i.folder] ?? 0) + 1;
      for (final t in i.meta.tags) {
        final k = t.toLowerCase();
        tc[k] = (tc[k] ?? 0) + 1;
        tagNames.putIfAbsent(k, () => t);
      }
      if (!i.meta.hasMemory) nm++;
      if (!i.meta.hasLocation) nl++;
    }
    _folderCounts = fc;
    _tagCounts = tc;
    noMemoryCount = nm;
    noLocationCount = nl;
    final r = root ?? '';
    folders = fc.keys.toList()
      ..sort((a, b) => p.relative(a, from: r).toLowerCase().compareTo(p.relative(b, from: r).toLowerCase()));
    final keys = tc.keys.toList()..sort((a, b) => tc[b]!.compareTo(tc[a]!));
    allTags = keys.map((k) => tagNames[k]!).toList();
  }

  void _resort() {
    _sorted = _items.values.toList()
      ..sort((a, b) {
        final c = a.sortDate.compareTo(b.sortDate);
        return c != 0 ? c : a.path.compareTo(b.path);
      });
  }

  // ───────────────────────── Navigasi & pilihan

  void setSource(Source s) {
    source = s;
    selected.clear();
    focused = null;
    _anchor = null;
    stopSlideshow();
    viewerOpen = false;
    _changed();
  }

  void setQuery(String q) {
    query = q;
    _changed();
  }

  void tapItem(PhotoItem item, {required bool toggle, required bool range}) {
    final vis = visible;
    final anchor = _anchor;
    if (range && anchor != null) {
      final a = vis.indexWhere((i) => i.path == anchor);
      final b = vis.indexWhere((i) => i.path == item.path);
      if (a >= 0 && b >= 0) {
        if (!toggle) selected.clear();
        for (var k = min(a, b); k <= max(a, b); k++) {
          selected.add(vis[k].path);
        }
      }
    } else if (toggle) {
      if (!selected.remove(item.path)) selected.add(item.path);
      _anchor = item.path;
    } else {
      selected
        ..clear()
        ..add(item.path);
      _anchor = item.path;
    }
    focused = item.path;
    notifyListeners();
  }

  void selectAll() {
    selected
      ..clear()
      ..addAll(visible.map((i) => i.path));
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    if (focused != null) selected.add(focused!);
    notifyListeners();
  }

  void openViewer(PhotoItem item) {
    focused = item.path;
    selected
      ..clear()
      ..add(item.path);
    _anchor = item.path;
    viewerOpen = true;
    notifyListeners();
  }

  void closeViewer() {
    stopSlideshow();
    viewerOpen = false;
    notifyListeners();
  }

  void focusAt(int index) {
    final vis = visible;
    if (vis.isEmpty) return;
    final item = vis[index.clamp(0, vis.length - 1)];
    focused = item.path;
    selected
      ..clear()
      ..add(item.path);
    _anchor = item.path;
    notifyListeners();
  }

  void step(int delta) {
    final vis = visible;
    if (vis.isEmpty) return;
    final idx = vis.indexWhere((i) => i.path == focused);
    focusAt(idx < 0 ? 0 : idx + delta);
  }

  void startSlideshow() {
    final vis = visible;
    if (vis.isEmpty) return;
    if (focusedItem == null) focusAt(0);
    viewerOpen = true;
    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final v = visible;
      final idx = v.indexWhere((i) => i.path == focused);
      focusAt(idx + 1 >= v.length ? 0 : idx + 1);
    });
    notifyListeners();
  }

  void stopSlideshow() {
    if (_slideTimer == null) return;
    _slideTimer?.cancel();
    _slideTimer = null;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  // ───────────────────────── Memindai

  Future<void> openRoot(String path) async {
    root = path;
    _items.clear();
    _sorted = [];
    source = const Source(SourceKind.all);
    selected.clear();
    focused = null;
    viewerOpen = false;
    _undo = null;
    _rebuildDerived();
    await _loadAlbums();
    _changed();
    await scan();
  }

  Future<void> scan() async {
    final r = root;
    final ex = exif;
    if (r == null || ex == null || scanning) return;
    scanning = true;
    progress = null;
    status = 'Mencari foto…';
    error = null;
    notifyListeners();
    try {
      final idxFile = IndexStore.fileFor(supportDir, r);
      final cached = await IndexStore.load(idxFile);

      final found = <String, FileStat>{};
      final lister = Directory(r).list(recursive: true, followLinks: false).handleError((_) {});
      await for (final ent in lister) {
        if (ent is! File) continue;
        final rel = p.relative(ent.path, from: r);
        if (p.split(rel).any((s) => s.startsWith('.'))) continue;
        if (!kPhotoExtensions.contains(p.extension(ent.path).toLowerCase())) continue;
        if (ent.path.contains('\n') || ent.path.contains('\r')) continue;
        found[ent.path] = await ent.stat();
      }

      final next = <String, PhotoItem>{};
      final toRead = <String>[];
      found.forEach((path, st) {
        final c = cached[path];
        if (c != null && c.size == st.size && c.modifiedMs == st.modified.millisecondsSinceEpoch) {
          next[path] = c;
        } else {
          toRead.add(path);
        }
      });

      final failed = <String>{};
      for (var i = 0; i < toRead.length; i += 100) {
        final chunk = toRead.sublist(i, min(i + 100, toRead.length));
        status = 'Membaca info foto ${i + chunk.length} dari ${toRead.length}…';
        progress = (i + chunk.length) / toRead.length;
        notifyListeners();
        Map<String, PhotoMeta> metas;
        try {
          metas = await ex.readMeta(chunk);
        } catch (_) {
          metas = {};
          failed.addAll(chunk);
        }
        for (final path in chunk) {
          final st = found[path]!;
          next[path] = PhotoItem(
            path: path,
            size: st.size,
            modifiedMs: st.modified.millisecondsSinceEpoch,
            meta: metas[path] ?? const PhotoMeta(),
          );
        }
      }

      _items
        ..clear()
        ..addAll(next);
      _resort();
      _rebuildDerived();
      if (focused != null && !_items.containsKey(focused)) focused = null;
      selected.removeWhere((s) => !_items.containsKey(s));
      await IndexStore.save(idxFile, next.values.where((i) => !failed.contains(i.path)));
      if (failed.isNotEmpty) {
        error = '${failed.length} foto gagal dibaca. Coba Pindai ulang.';
      }
    } catch (e) {
      error = 'Gagal memindai folder: $e';
    } finally {
      scanning = false;
      progress = null;
      status = null;
      _changed();
    }
  }

  Future<void> _saveIndex() async {
    final r = root;
    if (r == null) return;
    try {
      await IndexStore.save(IndexStore.fileFor(supportDir, r), _items.values);
    } catch (_) {}
  }

  // ───────────────────────── Album (berbasis tag)

  Future<void> _loadAlbums() async {
    albums = [];
    final r = root;
    if (r == null) return;
    try {
      final j = jsonDecode(await File(p.join(r, kAlbumFile)).readAsString()) as Map<String, dynamic>;
      albums = ((j['album'] as List?) ?? const [])
          .map((e) => AlbumDef.fromJson((e as Map).cast<String, dynamic>()))
          .where((a) => a.name.isNotEmpty && a.tag.isNotEmpty)
          .toList();
    } catch (_) {}
  }

  Future<void> _saveAlbums() async {
    final r = root;
    if (r == null) return;
    final f = File(p.join(r, kAlbumFile));
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'versi': 1,
      'keterangan': 'Daftar album Kenang. Album = semua foto dengan tag tertentu.',
      'album': albums.map((a) => a.toJson()).toList(),
    }));
  }

  Future<void> addAlbum(AlbumDef a) async {
    albums = [...albums.where((x) => x.name != a.name), a];
    _changed();
    await _saveAlbums();
  }

  Future<void> removeAlbum(String name) async {
    albums = albums.where((a) => a.name != name).toList();
    if (source.kind == SourceKind.album && source.key == name) {
      source = const Source(SourceKind.all);
    }
    _changed();
    await _saveAlbums();
  }

  // ───────────────────────── Menulis info ke foto

  /// Menulis perubahan ke file foto. Mengembalikan jumlah foto yang ditulis.
  Future<int> applyChanges(
    Map<PhotoItem, PhotoMeta> changes, {
    required String label,
    void Function(int done, int total)? onProgress,
    bool recordUndo = true,
  }) async {
    final ex = exif;
    if (ex == null) throw StateError('ExifTool belum tersedia');

    final groups = <String, (MetaWrite, List<PhotoItem>)>{};
    final before = <String, PhotoMeta>{};
    changes.forEach((item, nm) {
      final w = diffMeta(item.meta, nm);
      if (w == null) return;
      before[item.path] = item.meta;
      groups.putIfAbsent(w.signature, () => (w, <PhotoItem>[])).$2.add(item);
    });
    if (before.isEmpty) return 0;

    busy = true;
    progress = 0;
    notifyListeners();
    var done = 0;
    final total = before.length;
    final applied = <String, PhotoMeta>{};
    try {
      for (final g in groups.values) {
        final items = g.$2;
        for (var i = 0; i < items.length; i += 50) {
          final chunk = items.sublist(i, min(i + 50, items.length));
          await ex.write(chunk.map((e) => e.path).toList(), g.$1);
          for (final it in chunk) {
            applied[it.path] = before[it.path]!;
            it.meta = changes[it]!;
            try {
              final st = await File(it.path).stat();
              it.size = st.size;
              it.modifiedMs = st.modified.millisecondsSinceEpoch;
            } catch (_) {}
          }
          done += chunk.length;
          progress = done / total;
          onProgress?.call(done, total);
          notifyListeners();
        }
      }
    } finally {
      if (recordUndo && applied.isNotEmpty) _undo = _Undo(label, applied);
      busy = false;
      progress = null;
      _rebuildDerived();
      _changed();
      await _saveIndex();
    }
    return done;
  }

  Future<void> undo() async {
    final u = _undo;
    if (u == null) return;
    _undo = null;
    final changes = <PhotoItem, PhotoMeta>{};
    u.before.forEach((path, m) {
      final it = _items[path];
      if (it != null) changes[it] = m;
    });
    await applyChanges(changes, label: 'Urungkan', recordUndo: false);
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    super.dispose();
  }
}

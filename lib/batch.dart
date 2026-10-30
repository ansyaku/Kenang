import 'package:path/path.dart' as p;

import 'models.dart';
import 'services/meta_codec.dart';
import 'util/format.dart';

enum WriteMode { fillEmpty, overwrite, append }

class BatchRequest {
  const BatchRequest({
    this.doTitle = false,
    this.doLocation = false,
    this.doMemory = false,
    this.doTags = false,
    this.titlePattern = '',
    this.locationName = '',
    this.lat,
    this.lon,
    this.memory = '',
    this.tags = const [],
    this.mode = WriteMode.fillEmpty,
  });

  final bool doTitle;
  final bool doLocation;
  final bool doMemory;
  final bool doTags;
  final String titlePattern;
  final String locationName;
  final double? lat;
  final double? lon;
  final String memory;
  final List<String> tags;
  final WriteMode mode;

  bool get anyField => doTitle || doLocation || doMemory || doTags;
}

/// {nomor} {folder} {tanggal} {berkas}
String expandPattern(String pattern, PhotoItem item, int number) {
  final date = item.meta.takenAt;
  return pattern
      .replaceAll('{nomor}', '$number')
      .replaceAll('{folder}', p.basename(item.folder))
      .replaceAll('{tanggal}', date == null ? '' : formatDateShort(date))
      .replaceAll('{berkas}', item.fileBase)
      .trim();
}

String _applyText(String old, String value, WriteMode mode, String sep) {
  if (value.isEmpty) return mode == WriteMode.overwrite ? '' : old;
  return switch (mode) {
    WriteMode.fillEmpty => old.trim().isEmpty ? value : old,
    WriteMode.overwrite => value,
    WriteMode.append => old.trim().isEmpty ? value : '$old$sep$value',
  };
}

/// Menghitung info baru untuk tiap foto. Hanya foto yang berubah dikembalikan.
/// Urutan [targets] menentukan {nomor}.
Map<PhotoItem, PhotoMeta> computeBatch(List<PhotoItem> targets, BatchRequest r) {
  final out = <PhotoItem, PhotoMeta>{};
  if (!r.anyField) return out;
  final newTags = cleanTags(r.tags);
  for (var i = 0; i < targets.length; i++) {
    final item = targets[i];
    final m = item.meta;
    var n = m;

    if (r.doTitle) {
      n = n.copyWith(title: _applyText(m.title, expandPattern(r.titlePattern, item, i + 1), r.mode, ' '));
    }
    if (r.doMemory) {
      n = n.copyWith(description: _applyText(m.description, r.memory.trim(), r.mode, '\n'));
    }
    if (r.doLocation) {
      // Lokasi tidak "disambung": mode Tambahkan diperlakukan seperti Isi yang kosong.
      final overwrite = r.mode == WriteMode.overwrite;
      final name = r.locationName.trim();
      if (name.isNotEmpty && (overwrite || m.locationName.trim().isEmpty)) {
        n = n.copyWith(locationName: name);
      }
      if (r.lat != null && r.lon != null && (overwrite || !m.hasGps)) {
        n = n.copyWith(lat: r.lat, lon: r.lon);
      }
    }
    if (r.doTags) {
      if (r.mode == WriteMode.overwrite) {
        n = n.copyWith(tags: newTags);
      } else if (r.mode == WriteMode.append) {
        n = n.copyWith(tags: mergeTags(m.tags, newTags));
      } else if (m.tags.isEmpty) {
        n = n.copyWith(tags: newTags);
      }
    }
    if (diffMeta(m, n) != null) out[item] = n;
  }
  return out;
}

class BatchPreview {
  int title = 0;
  int location = 0;
  int memory = 0;
  int tags = 0;
  int total = 0;
}

BatchPreview summarize(Map<PhotoItem, PhotoMeta> changes) {
  final s = BatchPreview();
  changes.forEach((item, n) {
    final m = item.meta;
    s.total++;
    if (m.title != n.title) s.title++;
    if (m.description != n.description) s.memory++;
    if (m.locationName != n.locationName || m.lat != n.lat || m.lon != n.lon) s.location++;
    if (!listEq(m.tags, n.tags)) s.tags++;
  });
  return s;
}

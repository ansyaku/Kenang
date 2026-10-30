import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models.dart';

/// Cache daftar foto + info-nya supaya pustaka cepat dibuka.
/// Kalau file ini terhapus, cukup pindai ulang: data aslinya ada di foto.
class IndexStore {
  static File fileFor(String supportDir, String root) =>
      File(p.join(supportDir, 'indeks_${md5.convert(utf8.encode(root))}.json'));

  static Future<Map<String, PhotoItem>> load(File f) async {
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (j['v'] != 1) return {};
      final items = (j['items'] as Map).cast<String, dynamic>();
      final out = <String, PhotoItem>{};
      items.forEach((path, v) {
        final m = (v as Map).cast<String, dynamic>();
        out[path] = PhotoItem(
          path: path,
          size: (m['s'] as num).toInt(),
          modifiedMs: (m['m'] as num).toInt(),
          meta: PhotoMeta.fromJson((m['meta'] as Map).cast<String, dynamic>()),
        );
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(File f, Iterable<PhotoItem> items) async {
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'v': 1,
      'items': {
        for (final i in items)
          i.path: {'s': i.size, 'm': i.modifiedMs, 'meta': i.meta.toJson()},
      },
    }));
    await tmp.rename(f.path);
  }
}

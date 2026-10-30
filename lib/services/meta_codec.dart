import 'dart:convert';

import '../models.dart';
import '../util/format.dart';

/// Tag yang dibaca dari tiap foto (ExifTool, dengan -G1 -n -ec).
const kReadTagArgs = [
  '-XMP-dc:Title', '-IPTC:ObjectName', '-XPTitle',
  '-XMP-dc:Description', '-IPTC:Caption-Abstract', '-EXIF:ImageDescription', '-XPComment',
  '-XMP-dc:Subject', '-IPTC:Keywords', '-XPKeywords',
  '-XMP-iptcCore:Location', '-IPTC:Sub-location', '-XMP-photoshop:City', '-IPTC:City',
  '-Composite:GPSLatitude', '-Composite:GPSLongitude',
  '-XMP-exif:GPSLatitude', '-XMP-exif:GPSLongitude',
  '-DateTimeOriginal', '-CreateDate', '-Model',
];

/// Escape gaya C untuk opsi -ec ExifTool (baris baru jadi \n).
String escapeC(String s) => s
    .replaceAll('\\', r'\\')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\n', r'\n')
    .replaceAll('\t', r'\t');

String unescapeC(String s) {
  if (!s.contains('\\')) return s;
  final b = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '\\' && i + 1 < s.length) {
      final n = s[i + 1];
      if (n == 'n') {
        b.write('\n');
        i += 2;
        continue;
      } else if (n == 't') {
        b.write('\t');
        i += 2;
        continue;
      } else if (n == 'r') {
        i += 2;
        continue;
      } else if (n == '\\') {
        b.write('\\');
        i += 2;
        continue;
      }
    }
    b.write(c);
    i++;
  }
  return b.toString();
}

bool _nonEmpty(Object? v) {
  if (v == null) return false;
  if (v is String) return v.trim().isNotEmpty;
  if (v is List) return v.isNotEmpty;
  return true;
}

String _bare(String key) {
  final i = key.indexOf(':');
  return i < 0 ? key : key.substring(i + 1);
}

Object? _lookup(Map<String, dynamic> m, List<String> keys, {bool fallback = true}) {
  for (final k in keys) {
    final v = m[k];
    if (_nonEmpty(v)) return v;
  }
  if (!fallback) return null;
  for (final k in keys) {
    final bare = _bare(k);
    for (final e in m.entries) {
      if (e.key == 'SourceFile') continue;
      if (_bare(e.key) == bare && _nonEmpty(e.value)) return e.value;
    }
  }
  return null;
}

String _asString(Object? v) {
  if (v == null) return '';
  if (v is List) return v.map((e) => unescapeC(e.toString())).join(', ').trim();
  return unescapeC(v.toString()).trim();
}

double? _asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

List<String> _asList(Object? v) {
  if (v == null) return const [];
  if (v is List) return cleanTags(v.map((e) => unescapeC(e.toString())));
  return cleanTags([unescapeC(v.toString())]);
}

final _dateRe = RegExp(r'^(\d{4})[:\-](\d{2})[:\-](\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?');

DateTime? parseExifDate(Object? v) {
  if (v == null) return null;
  final m = _dateRe.firstMatch(v.toString().trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (y < 1900 || mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(y, mo, d, int.parse(m.group(4)!), int.parse(m.group(5)!),
      int.tryParse(m.group(6) ?? '') ?? 0);
}

/// Mengubah satu objek JSON dari `exiftool -j -G1 -n -ec` menjadi PhotoMeta.
PhotoMeta parseExifJson(Map<String, dynamic> m) {
  final title = _asString(_lookup(m, ['XMP-dc:Title', 'IPTC:ObjectName', 'IFD0:XPTitle']));
  final desc = _asString(_lookup(m, [
    'XMP-dc:Description', 'IPTC:Caption-Abstract', 'IFD0:ImageDescription', 'IFD0:XPComment',
  ]));

  var tags = _asList(_lookup(m, ['XMP-dc:Subject'], fallback: false));
  if (tags.isEmpty) tags = _asList(_lookup(m, ['IPTC:Keywords'], fallback: false));
  if (tags.isEmpty) {
    final xp = _lookup(m, ['IFD0:XPKeywords']);
    if (xp != null) tags = cleanTags(_asString(xp).split(';'));
  }

  final loc = _asString(_lookup(m, [
    'XMP-iptcCore:Location', 'IPTC:Sub-location', 'XMP-photoshop:City', 'IPTC:City',
  ]));

  var lat = _asDouble(_lookup(m, ['Composite:GPSLatitude'], fallback: false));
  var lon = _asDouble(_lookup(m, ['Composite:GPSLongitude'], fallback: false));
  if (lat == null || lon == null) {
    lat = _asDouble(_lookup(m, ['XMP-exif:GPSLatitude'], fallback: false));
    lon = _asDouble(_lookup(m, ['XMP-exif:GPSLongitude'], fallback: false));
  }
  if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180 || (lat == 0 && lon == 0)) {
    lat = null;
    lon = null;
  }

  final taken = parseExifDate(_lookup(m, ['ExifIFD:DateTimeOriginal', 'ExifIFD:CreateDate'])) ??
      parseExifDate(_lookup(m, ['QuickTime:CreateDate', 'XMP-xmp:CreateDate']));

  return PhotoMeta(
    title: title,
    description: desc,
    locationName: loc,
    lat: lat,
    lon: lon,
    tags: tags,
    takenAt: taken,
    camera: _asString(_lookup(m, ['IFD0:Model'])),
  );
}

/// Kolom yang akan ditulis. `null` = tidak disentuh.
class MetaWrite {
  const MetaWrite({
    this.title,
    this.description,
    this.locationName,
    this.tags,
    this.setGps = false,
    this.lat,
    this.lon,
  });

  final String? title;
  final String? description;
  final String? locationName;
  final List<String>? tags;
  final bool setGps;
  final double? lat;
  final double? lon;

  bool get isEmpty =>
      title == null && description == null && locationName == null && tags == null && !setGps;

  bool get touchesIptc =>
      title != null || description != null || locationName != null || tags != null;

  String get signature => jsonEncode({
        't': title,
        'd': description,
        'l': locationName,
        'g': tags,
        's': setGps,
        'a': setGps ? lat : null,
        'o': setGps ? lon : null,
      });

  /// Argumen ExifTool. Nilai yang sama ditulis ke beberapa kolom standar
  /// supaya terbaca juga di Apple Photos, Windows Explorer, Lightroom, dll.
  List<String> toArgs() {
    final a = <String>[];
    void put(String tag, String v) => a.add('-$tag=${escapeC(v)}');

    final t = title;
    if (t != null) {
      for (final tag in ['XMP-dc:Title', 'IPTC:ObjectName', 'EXIF:XPTitle']) {
        put(tag, t);
      }
    }
    final d = description;
    if (d != null) {
      for (final tag in [
        'XMP-dc:Description', 'IPTC:Caption-Abstract', 'EXIF:ImageDescription', 'EXIF:XPComment',
      ]) {
        put(tag, d);
      }
    }
    final l = locationName;
    if (l != null) {
      for (final tag in ['XMP-iptcCore:Location', 'IPTC:Sub-location']) {
        put(tag, l);
      }
    }
    final tg = tags;
    if (tg != null) {
      final clean = cleanTags(tg);
      if (clean.isEmpty) {
        a.addAll(['-XMP-dc:Subject=', '-IPTC:Keywords=', '-EXIF:XPKeywords=']);
      } else {
        // Penugasan berulang pada tag daftar = mengganti seluruh daftar.
        for (final x in clean) {
          put('XMP-dc:Subject', x);
        }
        for (final x in clean) {
          put('IPTC:Keywords', x);
        }
        put('EXIF:XPKeywords', clean.join(';'));
      }
    }
    if (setGps) {
      final la = lat, lo = lon;
      if (la == null || lo == null) {
        a.addAll([
          '-GPSLatitude*=', '-GPSLongitude*=',
          '-XMP-exif:GPSLatitude=', '-XMP-exif:GPSLongitude=',
        ]);
      } else {
        final sLa = la.toStringAsFixed(6), sLo = lo.toStringAsFixed(6);
        a.addAll([
          '-GPSLatitude*=$sLa', '-GPSLongitude*=$sLo',
          '-XMP-exif:GPSLatitude=$sLa', '-XMP-exif:GPSLongitude=$sLo',
        ]);
      }
    }
    return a;
  }
}

/// Kolom apa saja yang berubah dari [a] ke [b]. `null` jika tidak ada.
MetaWrite? diffMeta(PhotoMeta a, PhotoMeta b) {
  final gpsChanged = a.lat != b.lat || a.lon != b.lon;
  final w = MetaWrite(
    title: a.title != b.title ? b.title : null,
    description: a.description != b.description ? b.description : null,
    locationName: a.locationName != b.locationName ? b.locationName : null,
    tags: listEq(a.tags, b.tags) ? null : b.tags,
    setGps: gpsChanged,
    lat: b.lat,
    lon: b.lon,
  );
  return w.isEmpty ? null : w;
}

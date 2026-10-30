import 'package:path/path.dart' as p;

/// Info yang tersimpan di dalam file foto.
class PhotoMeta {
  const PhotoMeta({
    this.title = '',
    this.description = '',
    this.locationName = '',
    this.lat,
    this.lon,
    this.tags = const [],
    this.takenAt,
    this.camera = '',
  });

  /// Nama foto.
  final String title;

  /// Memori / keterangan.
  final String description;

  /// Nama tempat (teks bebas).
  final String locationName;
  final double? lat;
  final double? lon;
  final List<String> tags;

  /// Hanya dibaca dari kamera, tidak pernah ditulis Kenang.
  final DateTime? takenAt;
  final String camera;

  bool get hasGps => lat != null && lon != null;
  bool get hasMemory => description.trim().isNotEmpty;
  bool get hasLocation => locationName.trim().isNotEmpty || hasGps;

  PhotoMeta copyWith({
    String? title,
    String? description,
    String? locationName,
    double? lat,
    double? lon,
    bool clearGps = false,
    List<String>? tags,
  }) {
    return PhotoMeta(
      title: title ?? this.title,
      description: description ?? this.description,
      locationName: locationName ?? this.locationName,
      lat: clearGps ? null : (lat ?? this.lat),
      lon: clearGps ? null : (lon ?? this.lon),
      tags: tags ?? this.tags,
      takenAt: takenAt,
      camera: camera,
    );
  }

  Map<String, dynamic> toJson() => {
        't': title,
        'd': description,
        'l': locationName,
        'lat': lat,
        'lon': lon,
        'tags': tags,
        'at': takenAt?.toIso8601String(),
        'cam': camera,
      };

  factory PhotoMeta.fromJson(Map<String, dynamic> j) {
    final at = j['at'];
    return PhotoMeta(
      title: (j['t'] ?? '').toString(),
      description: (j['d'] ?? '').toString(),
      locationName: (j['l'] ?? '').toString(),
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      tags: ((j['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
      takenAt: at is String ? DateTime.tryParse(at) : null,
      camera: (j['cam'] ?? '').toString(),
    );
  }
}

/// Satu file foto di pustaka.
class PhotoItem {
  PhotoItem({
    required this.path,
    required this.size,
    required this.modifiedMs,
    required this.meta,
  });

  final String path;
  int size;
  int modifiedMs;
  PhotoMeta meta;

  String get folder => p.dirname(path);
  String get fileName => p.basename(path);
  String get fileBase => p.basenameWithoutExtension(path);
  DateTime get sortDate =>
      meta.takenAt ?? DateTime.fromMillisecondsSinceEpoch(modifiedMs);
}

/// Album = kumpulan foto dengan tag tertentu, lintas folder.
class AlbumDef {
  const AlbumDef({required this.name, required this.tag});
  final String name;
  final String tag;

  Map<String, dynamic> toJson() => {'nama': name, 'tag': tag};

  factory AlbumDef.fromJson(Map<String, dynamic> j) =>
      AlbumDef(name: (j['nama'] ?? '').toString(), tag: (j['tag'] ?? '').toString());
}

const kPhotoExtensions = {
  '.jpg', '.jpeg', '.heic', '.heif', '.png', '.webp', '.tif', '.tiff',
};

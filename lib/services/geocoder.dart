import 'dart:convert';

import 'package:http/http.dart' as http;

const kUserAgent = 'Kenang/0.1 (aplikasi album foto pribadi)';

class GeoPlace {
  const GeoPlace(this.label, this.lat, this.lon);
  final String label;
  final double lat;
  final double lon;

  /// "Tegallalang, Gianyar, Bali, Indonesia" -> "Tegallalang, Gianyar"
  String get shortName {
    final parts = label.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return parts.take(2).join(', ');
  }
}

/// Mencari koordinat dari nama tempat lewat OpenStreetMap (Nominatim).
class Geocoder {
  Future<List<GeoPlace>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '6',
      'accept-language': 'id',
    });
    final r = await http
        .get(uri, headers: {'User-Agent': kUserAgent})
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw Exception('Pencarian lokasi gagal (kode ${r.statusCode})');
    }
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    final out = <GeoPlace>[];
    for (final e in list) {
      final m = e as Map;
      final lat = double.tryParse(m['lat'].toString());
      final lon = double.tryParse(m['lon'].toString());
      if (lat == null || lon == null) continue;
      out.add(GeoPlace((m['display_name'] ?? q).toString(), lat, lon));
    }
    return out;
  }
}

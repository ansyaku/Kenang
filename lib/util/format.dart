const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

String _two(int n) => n.toString().padLeft(2, '0');

/// "Kamis, 14 Agustus 2025 · 06.42"
String formatDateLong(DateTime d) =>
    '${_hari[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]} ${d.year} · ${_two(d.hour)}.${_two(d.minute)}';

/// "14 Agustus 2025"
String formatDateShort(DateTime d) => '${d.day} ${_bulan[d.month - 1]} ${d.year}';

/// "Anjing, mochi ,anjing" -> ["Anjing", "mochi"]
List<String> parseTags(String input) => cleanTags(input.split(RegExp(r'[,;\n]')));

List<String> cleanTags(Iterable<String> tags) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in tags) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    if (seen.add(t.toLowerCase())) out.add(t);
  }
  return out;
}

List<String> mergeTags(List<String> a, List<String> b) => cleanTags([...a, ...b]);

double? parseCoord(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String formatCoords(double lat, double lon) =>
    '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

bool listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

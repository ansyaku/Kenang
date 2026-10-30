import 'package:flutter_test/flutter_test.dart';
import 'package:kenang/batch.dart';
import 'package:kenang/models.dart';
import 'package:kenang/services/meta_codec.dart';
import 'package:kenang/util/format.dart';

PhotoItem _item(String path, PhotoMeta meta) =>
    PhotoItem(path: path, size: 1, modifiedMs: 0, meta: meta);

void main() {
  group('escape -ec', () {
    test('baris baru dan backslash bolak-balik', () {
      const s = 'Baris satu\nBaris dua \\ selesai';
      expect(escapeC(s).contains('\n'), isFalse);
      expect(unescapeC(escapeC(s)), s);
    });
  });

  group('parseExifJson', () {
    test('membaca nama, memori, tag, GPS, tanggal', () {
      final m = parseExifJson({
        'SourceFile': '/a/b.jpg',
        'XMP-dc:Title': 'Sawah pagi',
        'IPTC:Caption-Abstract': 'Kabut\\nbaris dua',
        'XMP-dc:Subject': ['Anjing', 'Mochi'],
        'XMP-iptcCore:Location': 'Ubud, Bali',
        'Composite:GPSLatitude': -8.4325,
        'Composite:GPSLongitude': 115.2794,
        'ExifIFD:DateTimeOriginal': '2025:08:14 06:42:00',
        'IFD0:Model': 'iPhone 15',
      });
      expect(m.title, 'Sawah pagi');
      expect(m.description, 'Kabut\nbaris dua');
      expect(m.tags, ['Anjing', 'Mochi']);
      expect(m.locationName, 'Ubud, Bali');
      expect(m.lat, closeTo(-8.4325, 1e-9));
      expect(m.takenAt, DateTime(2025, 8, 14, 6, 42));
      expect(m.camera, 'iPhone 15');
    });

    test('tag dari XPKeywords dipisah titik koma', () {
      final m = parseExifJson({'IFD0:XPKeywords': 'Anjing;Rumah'});
      expect(m.tags, ['Anjing', 'Rumah']);
    });
  });

  group('MetaWrite', () {
    test('tag ditulis ke XMP, IPTC, dan Windows', () {
      final args = const MetaWrite(tags: ['Anjing', 'Mochi']).toArgs();
      expect(args, containsAll(['-XMP-dc:Subject=Anjing', '-IPTC:Keywords=Mochi', '-EXIF:XPKeywords=Anjing;Mochi']));
    });

    test('memori multi-baris di-escape', () {
      final args = const MetaWrite(description: 'a\nb').toArgs();
      expect(args.every((a) => !a.contains('\n')), isTrue);
    });

    test('diffMeta hanya kolom yang berubah', () {
      const a = PhotoMeta(title: 'A', tags: ['x']);
      final w = diffMeta(a, a.copyWith(title: 'B'))!;
      expect(w.title, 'B');
      expect(w.tags, isNull);
      expect(w.setGps, isFalse);
      expect(diffMeta(a, a), isNull);
    });
  });

  group('edit massal', () {
    final items = [
      _item('/f/Bali/1.jpg', const PhotoMeta()),
      _item('/f/Bali/2.jpg', const PhotoMeta(title: 'Sudah ada', tags: ['Pantai'])),
    ];

    test('isi yang kosong saja + pola nomor', () {
      final c = computeBatch(items, const BatchRequest(doTitle: true, titlePattern: '{folder} #{nomor}'));
      expect(c.length, 1);
      expect(c[items[0]]!.title, 'Bali #1');
    });

    test('tambahkan tag menggabungkan tanpa dobel', () {
      final c = computeBatch(items, const BatchRequest(doTags: true, tags: ['pantai', 'Liburan'], mode: WriteMode.append));
      expect(c[items[1]]!.tags, ['Pantai', 'Liburan']);
      expect(c[items[0]]!.tags, ['pantai', 'Liburan']);
    });

    test('timpa lokasi + GPS', () {
      final c = computeBatch(items, const BatchRequest(
        doLocation: true, locationName: 'Ubud', lat: -8.5, lon: 115.26, mode: WriteMode.overwrite));
      expect(c.length, 2);
      expect(c[items[1]]!.hasGps, isTrue);
    });
  });

  test('parseTags', () {
    expect(parseTags(' Anjing, mochi ,anjing,,'), ['Anjing', 'mochi']);
  });
}

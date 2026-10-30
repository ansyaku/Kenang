# Kenang — versi Mac 0.1

Penampil foto yang menyimpan **Nama**, **Lokasi**, **Memori**, dan **Tag** langsung di dalam file foto
(metadata XMP/IPTC/EXIF), sehingga datanya ikut ke mana pun fotonya pergi.

## Persiapan (sekali saja)

Buka **Terminal** di Mac, lalu jalankan baris-baris ini:

```bash
# 1. Homebrew (lewati kalau sudah punya)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Xcode: pasang dari App Store, buka sekali, lalu:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# 3. Flutter, CocoaPods, dan ExifTool
brew install --cask flutter
brew install cocoapods exiftool

# 4. Cek. Bagian "Xcode" dan "macOS" harus centang hijau.
flutter doctor
```

## Menjalankan

```bash
cd ~/Downloads/kenang          # sesuaikan dengan lokasi folder ini
chmod +x tool/setup_macos.sh
./tool/setup_macos.sh          # membuat file macOS, mematikan sandbox, ambil paket

flutter run -d macos           # coba jalankan
```

Untuk aplikasi jadi:

```bash
flutter build macos --release
open build/macos/Build/Products/Release/
```

Seret **Kenang.app** ke folder Applications. Hasil build sudah universal, jadi jalan native di Apple Silicon.

## Cara pakai

- **Pertama kali**: pilih folder foto utama, misalnya folder di iCloud Drive atau pCloud Drive. Semua subfolder ikut dibaca.
- **Klik** foto untuk melihat info di panel kanan. **Klik dua kali** atau **Spasi** untuk memperbesar.
- **Edit info**: isi nama, lokasi, memori, dan tag, lalu Simpan (⌘S). Info langsung ditulis ke dalam file foto.
- **Edit massal**: ⌘-klik / Shift-klik beberapa foto, atau ⌘A untuk semua. Panel kanan berubah jadi edit massal:
  centang kolom yang mau diisi, pilih cara menulis, lihat pratinjau, lalu Terapkan.
- **Urungkan**: tombol ↶ di atas, atau "Urungkan" di pesan setelah menyimpan. Membatalkan perubahan terakhir.
- **Album**: klik + di samping "Album" di sidebar. Album = semua foto dengan tag tertentu, dari folder mana pun,
  tanpa menyalin file. Daftar album disimpan di `koleksi.kenang.json` di folder utama.
- **Tema**: tombol otomatis / cerah / gelap di kanan atas.

| Tombol | Fungsi |
|---|---|
| ← → | Foto sebelumnya / berikutnya |
| Spasi / Enter | Buka / tutup tampilan besar |
| Esc | Kembali ke grid / batal pilih |
| ⌘A | Pilih semua di tampilan ini |
| ⌘S | Simpan (saat mengedit) |

## Di mana data disimpan

| Apa | Tempat |
|---|---|
| Nama, memori, lokasi, GPS, tag | Di dalam file foto (beberapa kolom standar sekaligus, supaya terbaca juga di Apple Photos, Windows, Lightroom) |
| Daftar album | `koleksi.kenang.json` di folder foto utama |
| Cache indeks (biar cepat) | `~/Library/Application Support/Kenang/` (aman dihapus) |
| Thumbnail | `~/Library/Caches/Kenang/` (aman dihapus) |

## Tips

- **Cadangkan dulu** satu folder sebelum mencoba edit massal pertama kali.
- iCloud Drive: klik kanan folder foto → **Keep Downloaded**, supaya file tidak cuma ikon awan.
- pCloud Drive: untuk folder yang sering dibuka, pakai fitur **Sync** pCloud supaya file ada di disk lokal dan lebih cepat.
- Foto yang dikirim lewat WhatsApp atau media sosial biasanya kehilangan metadata. Bagikan file aslinya.
- Peta kecil dan "Cari koordinat" butuh internet (OpenStreetMap).

## Batasan versi ini

- Belum ada nama tampilan untuk folder (masih memakai nama folder asli).
- Versi HP (lihat saja) belum dibuat.
- Kode belum pernah di-build. Kalau `flutter run` memunculkan error, salin pesannya untuk diperbaiki.

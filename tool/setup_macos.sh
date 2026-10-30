#!/bin/bash
# Menyiapkan folder macOS untuk Kenang. Jalankan sekali dari folder proyek:
#   ./tool/setup_macos.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter belum terpasang. Lihat README.md bagian 'Persiapan'." >&2
  exit 1
fi

echo "› Membuat file platform macOS (file di lib/ tidak ditimpa)…"
flutter create --platforms=macos --org id.kenang --project-name kenang . >/dev/null

echo "› Mematikan App Sandbox (agar bisa menjalankan ExifTool & membaca folder foto)…"
for f in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
  /usr/libexec/PlistBuddy -c "Set :com.apple.security.app-sandbox false" "$f" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :com.apple.security.app-sandbox bool false" "$f"
done

echo "› Memberi nama aplikasi 'Kenang'…"
sed -i '' 's/^PRODUCT_NAME = .*/PRODUCT_NAME = Kenang/' macos/Runner/Configs/AppInfo.xcconfig

echo "› Mengambil paket Dart…"
flutter pub get >/dev/null

if command -v exiftool >/dev/null 2>&1; then
  echo "✓ ExifTool ditemukan: $(exiftool -ver)"
else
  echo "! ExifTool belum ada. Pasang dengan: brew install exiftool"
fi

echo
echo "Selesai. Coba jalankan:  flutter run -d macos"
echo "Atau build aplikasi:     flutter build macos --release"

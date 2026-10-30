import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

/// Layar awal: memasang ExifTool atau memilih folder foto utama.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final needExif = app.exifPath == null;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kenang', style: kSerif.copyWith(fontSize: 52, color: pal.text)),
                const SizedBox(height: 8),
                Text(
                  'Foto, beserta nama, tempat, dan ceritanya.',
                  style: TextStyle(color: pal.muted, fontSize: 15),
                ),
                const SizedBox(height: 32),
                if (app.checkingExif)
                  const LinearProgressIndicator(minHeight: 2)
                else if (needExif) ...[
                  const Text('ExifTool belum terpasang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'Kenang memakai ExifTool untuk membaca dan menulis nama, lokasi, memori, '
                    'dan tag langsung di dalam file foto. Pasang lewat Terminal:',
                    style: TextStyle(color: pal.muted, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(8)),
                    child: const SelectableText(
                      'brew install exiftool',
                      style: TextStyle(fontFamily: 'Menlo', fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Belum punya Homebrew? Unduh paket macOS (.pkg) dari exiftool.org.',
                    style: TextStyle(color: pal.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: app.detectExif, child: const Text('Sudah, cek lagi')),
                ] else ...[
                  const Text('Pilih folder foto utamamu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'Misalnya folder "Foto" di iCloud Drive atau pCloud Drive. '
                    'Semua subfolder di dalamnya ikut dibaca. Tidak ada foto yang dipindah atau disalin.',
                    style: TextStyle(color: pal.muted, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: app.pickRoot,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: const Text('Pilih folder'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

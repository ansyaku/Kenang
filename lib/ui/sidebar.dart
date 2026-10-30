import 'package:flutter/material.dart';

import '../app_state.dart';
import '../library.dart';
import '../theme.dart';
import 'common.dart';
import 'dialogs.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final lib = app.library;
    final pal = context.pal;
    final src = lib.source;

    Future<void> newAlbum() async {
      final a = await showAlbumDialog(context, app);
      if (a == null) return;
      await lib.addAlbum(a);
      lib.setSource(Source(SourceKind.album, a.name));
    }

    Future<void> albumMenu(String name, Offset pos) async {
      final choice = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
        items: const [PopupMenuItem(value: 'hapus', child: Text('Hapus album'))],
      );
      if (choice == 'hapus') {
        await lib.removeAlbum(name);
        if (context.mounted) {
          showMessage(context, 'Album "$name" dihapus. Tag di foto tidak diubah.');
        }
      }
    }

    return Container(
      color: pal.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 24),
        children: [
          const _Header('Pustaka'),
          _NavRow(
            icon: Icons.photo_library_outlined,
            label: 'Semua foto',
            count: lib.totalCount,
            selected: src.kind == SourceKind.all,
            onTap: () => lib.setSource(const Source(SourceKind.all)),
          ),
          _NavRow(
            icon: Icons.edit_note_outlined,
            label: 'Belum ada memori',
            count: lib.noMemoryCount,
            highlightCount: lib.noMemoryCount > 0,
            selected: src.kind == SourceKind.noMemory,
            onTap: () => lib.setSource(const Source(SourceKind.noMemory)),
          ),
          _NavRow(
            icon: Icons.location_off_outlined,
            label: 'Tanpa lokasi',
            count: lib.noLocationCount,
            selected: src.kind == SourceKind.noLocation,
            onTap: () => lib.setSource(const Source(SourceKind.noLocation)),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: _Header('Album')),
            IconButton(
              tooltip: 'Album baru',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: newAlbum,
              icon: const Icon(Icons.add),
            ),
          ]),
          if (lib.albums.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Text(
                'Buat album dari tag, misal semua foto bertag "Anjing".',
                style: TextStyle(fontSize: 12, color: pal.muted, height: 1.4),
              ),
            ),
          for (final a in lib.albums)
            GestureDetector(
              onSecondaryTapDown: (d) => albumMenu(a.name, d.globalPosition),
              child: _NavRow(
                icon: Icons.collections_bookmark_outlined,
                label: a.name,
                count: lib.tagCount(a.tag),
                selected: src.kind == SourceKind.album && src.key == a.name,
                tooltip: 'Tag: ${a.tag} · klik kanan untuk menghapus',
                onTap: () => lib.setSource(Source(SourceKind.album, a.name)),
              ),
            ),
          const SizedBox(height: 18),
          const _Header('Folder'),
          for (final f in lib.folders)
            _NavRow(
              icon: Icons.folder_outlined,
              label: lib.folderLabel(f),
              count: lib.folderCount(f),
              selected: src.kind == SourceKind.folder && src.key == f,
              onTap: () => lib.setSource(Source(SourceKind.folder, f)),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 8), child: SectionLabel(text));
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.highlightCount = false,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final bool highlightCount;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fg = selected ? pal.accentText : pal.text;
    Widget row = Material(
      color: selected ? pal.surface2 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Icon(icon, size: 17, color: selected ? pal.accentText : pal.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: fg),
                ),
              ),
              const SizedBox(width: 6),
              if (highlightCount)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: pal.accentSoft, borderRadius: BorderRadius.circular(999)),
                  child: Text('$count', style: TextStyle(fontSize: 11.5, color: pal.accentText)),
                )
              else
                Text('$count', style: TextStyle(fontSize: 12, color: pal.muted)),
            ]),
          ),
        ),
      ),
    );
    if (tooltip != null) row = Tooltip(message: tooltip!, child: row);
    return Padding(padding: const EdgeInsets.only(bottom: 2), child: row);
  }
}

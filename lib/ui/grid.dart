import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'PhotoThumb.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final lib = app.library;
    final pal = context.pal;
    final items = lib.visible;
    final nSel = lib.selected.length;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Row(children: [
        Text(
          nSel > 1 ? '${items.length} foto · $nSel dipilih' : '${items.length} foto',
          style: TextStyle(color: pal.muted, fontSize: 13),
        ),
        const Spacer(),
        TextButton(
          onPressed: items.isEmpty ? null : lib.selectAll,
          child: Text('Pilih semua (${items.length})'),
        ),
        if (nSel > 1) TextButton(onPressed: lib.clearSelection, child: const Text('Batal pilih')),
        const SizedBox(width: 4),
        OutlinedButton.icon(
          onPressed: items.isEmpty ? null : lib.startSlideshow,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Slideshow'),
        ),
      ]),
    );

    if (items.isEmpty) {
      final msg = lib.scanning
          ? (lib.status ?? 'Memindai…')
          : lib.query.trim().isNotEmpty
              ? 'Tidak ada foto yang cocok dengan "${lib.query.trim()}".'
              : 'Belum ada foto di sini.';
      return Column(children: [
        header,
        Expanded(child: Center(child: Text(msg, style: TextStyle(color: pal.muted)))),
      ]);
    }

    return Column(children: [
      header,
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final it = items[i];
            return PhotoTile(
              key: ValueKey(it.path),
              app: app,
              item: it,
              selected: lib.selected.contains(it.path) && (nSel > 1 || lib.focused == it.path),
              multi: nSel > 1,
            );
          },
        ),
      ),
    ]);
  }
}

class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.app, required this.item, required this.selected, required this.multi});

  final AppState app;
  final PhotoItem item;
  final bool selected;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = app.library;
    final m = item.meta;
    final kb = HardwareKeyboard.instance;

    return Listener(
      onPointerDown: (e) {
        if (e.buttons != kPrimaryMouseButton) return;
        app.homeFocus.requestFocus();
        lib.tapItem(item, toggle: kb.isMetaPressed || kb.isControlPressed, range: kb.isShiftPressed);
      },
      child: GestureDetector(
        onDoubleTap: () => lib.openViewer(item),
        child: Semantics(
          button: true,
          selected: selected,
          label: m.title.isNotEmpty ? m.title : item.fileName,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: selected ? pal.accent : Colors.transparent, width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(fit: StackFit.expand, children: [
                PhotoThumb(app: app, path: item.path),
                if (m.title.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: Text(
                        m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5),
                      ),
                    ),
                  ),
                if (m.hasMemory)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: const _Badge(icon: Icons.chat_bubble_outline_rounded),
                  ),
                if (multi && selected)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: pal.accent, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, size: 16, color: pal.onAccent),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
        child: Icon(icon, size: 13, color: const Color(0xFFF3C873)),
      );
}

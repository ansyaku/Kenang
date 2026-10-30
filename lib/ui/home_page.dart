import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme.dart';
import 'batch_panel.dart';
import 'common.dart';
import 'grid.dart';
import 'info_panel.dart';
import 'setup_screen.dart';
import 'sidebar.dart';
import 'viewer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.library]),
      builder: (context, _) {
        final lib = app.library;
        if (app.exifPath == null || lib.root == null) return SetupScreen(app: app);
        return Focus(
          focusNode: app.homeFocus,
          autofocus: true,
          onKeyEvent: (node, e) => _onKey(e),
          child: Scaffold(
            body: Column(children: [
              _TopBar(app: app),
              SizedBox(
                height: 2,
                child: (lib.scanning || lib.busy)
                    ? LinearProgressIndicator(value: lib.progress, minHeight: 2)
                    : null,
              ),
              if (lib.error != null) _ErrorBanner(message: lib.error!, onClose: lib.clearError),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(width: 240, child: Sidebar(app: app)),
                  const VerticalDivider(width: 1),
                  Expanded(child: lib.viewerOpen ? ViewerView(app: app) : PhotoGrid(app: app)),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 360, child: _RightPanel(app: app)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  KeyEventResult _onKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    // Jangan ganggu saat sedang mengetik di kolom teks.
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx != null && ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final lib = app.library;
    final k = e.logicalKey;
    final meta = HardwareKeyboard.instance.isMetaPressed;

    if (meta && k == LogicalKeyboardKey.keyA) {
      lib.selectAll();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (lib.viewerOpen) {
        lib.closeViewer();
      } else {
        lib.clearSelection();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      lib.step(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      lib.step(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      final f = lib.focusedItem;
      if (lib.viewerOpen) {
        lib.closeViewer();
      } else if (f != null) {
        lib.openViewer(f);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = app.library;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(bottom: BorderSide(color: pal.border)),
      ),
      child: Row(children: [
        Text('Kenang', style: kSerif.copyWith(fontSize: 26, color: pal.text)),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            lib.sourceTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: pal.muted, fontSize: 13.5),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 260, child: _SearchField(app: app)),
        const SizedBox(width: 8),
        if (lib.canUndo)
          IconButton(
            tooltip: 'Urungkan: ${lib.undoLabel}',
            onPressed: () async {
              try {
                await lib.undo();
              } catch (e) {
                if (context.mounted) showMessage(context, 'Gagal membatalkan: $e');
              }
            },
            icon: const Icon(Icons.undo_rounded),
          ),
        IconButton(
          tooltip: 'Pindai ulang folder',
          onPressed: lib.scanning ? null : lib.scan,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 4),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined, size: 18), tooltip: 'Ikuti sistem'),
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18), tooltip: 'Cerah'),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18), tooltip: 'Gelap'),
          ],
          selected: {app.settings.themeMode},
          onSelectionChanged: (s) => app.settings.setTheme(s.first),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: app.pickRoot,
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('Ganti folder'),
        ),
      ]),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.app});
  final AppState app;
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _c = TextEditingController(text: widget.app.library.query);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return TextField(
      controller: _c,
      onChanged: widget.app.library.setQuery,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Cari nama, lokasi, memori, tag…',
        prefixIcon: Icon(Icons.search, size: 18, color: pal.muted),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                iconSize: 16,
                onPressed: () {
                  _c.clear();
                  widget.app.library.setQuery('');
                  widget.app.homeFocus.requestFocus();
                },
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final lib = app.library;
    final pal = context.pal;
    final sel = lib.selectedItems;
    if (sel.length > 1) {
      return BatchPanel(key: const ValueKey('batch'), app: app, targets: sel);
    }
    final f = lib.focusedItem;
    if (f != null) return InfoPanel(key: ValueKey(f.path), app: app, item: f);

    final n = lib.visible.length;
    return Container(
      color: pal.surface,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pilih sebuah foto', style: kSerif.copyWith(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            'Klik untuk melihat info. Klik dua kali untuk memperbesar.\n'
            '⌘-klik atau Shift-klik untuk memilih beberapa foto sekaligus.',
            style: TextStyle(color: pal.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: n == 0 ? null : lib.selectAll,
            child: Text('Edit massal semua di tampilan ini ($n)'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.accentSoft,
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: pal.accentText),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: pal.text, fontSize: 13))),
        IconButton(tooltip: 'Tutup', iconSize: 16, onPressed: onClose, icon: const Icon(Icons.close)),
      ]),
    );
  }
}

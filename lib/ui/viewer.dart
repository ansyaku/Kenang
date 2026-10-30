import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'PhotoThumb.dart';

class ViewerView extends StatefulWidget {
  const ViewerView({super.key, required this.app});
  final AppState app;

  @override
  State<ViewerView> createState() => _ViewerViewState();
}

class _ViewerViewState extends State<ViewerView> {
  final _strip = ScrollController();
  int _lastIdx = -1;
  static const _cell = 84.0;

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  void _scrollStripTo(int idx) {
    if (idx == _lastIdx) return;
    _lastIdx = idx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_strip.hasClients) return;
      final pos = _strip.position;
      final target = (idx * _cell - pos.viewportDimension / 2 + _cell / 2).clamp(0.0, pos.maxScrollExtent);
      _strip.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final lib = app.library;
    final pal = context.pal;
    final items = lib.visible;
    final idx = items.indexWhere((i) => i.path == lib.focused);
    if (idx < 0) {
      return Center(
        child: TextButton(onPressed: lib.closeViewer, child: const Text('Kembali ke grid')),
      );
    }
    final item = items[idx];
    _scrollStripTo(idx);

    return Container(
      color: pal.viewerBg,
      child: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Stack(children: [
              Positioned.fill(
                child: PhotoThumb(key: ValueKey('t-${item.path}'), app: app, path: item.path, fit: BoxFit.contain),
              ),
              Positioned.fill(
                child: PhotoThumb(
                  key: ValueKey('l-${item.path}'),
                  app: app,
                  path: item.path,
                  large: true,
                  fit: BoxFit.contain,
                  showPlaceholder: false,
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: RoundButton(icon: Icons.grid_view_rounded, tooltip: 'Kembali ke grid (Esc)', onPressed: lib.closeViewer),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: RoundButton(
                  icon: lib.slideshow ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  tooltip: lib.slideshow ? 'Hentikan slideshow' : 'Mulai slideshow',
                  onPressed: lib.slideshow ? lib.stopSlideshow : lib.startSlideshow,
                ),
              ),
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: RoundButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Foto sebelumnya (←)',
                    onPressed: idx > 0 ? () => lib.step(-1) : null,
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: RoundButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Foto berikutnya (→)',
                    onPressed: idx < items.length - 1 ? () => lib.step(1) : null,
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.fileName} · ${idx + 1} dari ${items.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ]),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.builder(
            controller: _strip,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            itemExtent: _cell,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              final active = i == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => lib.focusAt(i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: active ? pal.accent : Colors.transparent, width: 2),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Opacity(
                        opacity: active ? 1 : 0.7,
                        child: PhotoThumb(key: ValueKey(it.path), app: app, path: it.path),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

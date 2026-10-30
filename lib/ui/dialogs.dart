import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/geocoder.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';

/// Membuat album baru dari sebuah tag.
Future<AlbumDef?> showAlbumDialog(BuildContext context, AppState app) {
  return showDialog<AlbumDef>(context: context, builder: (_) => _AlbumDialog(app: app));
}

class _AlbumDialog extends StatefulWidget {
  const _AlbumDialog({required this.app});
  final AppState app;
  @override
  State<_AlbumDialog> createState() => _AlbumDialogState();
}

class _AlbumDialogState extends State<_AlbumDialog> {
  final _name = TextEditingController();
  final _tag = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final tag = _tag.text.trim();
    if (name.isEmpty || tag.isEmpty) return;
    Navigator.of(context).pop(AlbumDef(name: name, tag: tag));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = widget.app.library;
    final suggestions = lib.allTags.take(14).toList();
    return AlertDialog(
      title: Text('Album baru', style: kSerif.copyWith(fontSize: 26)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Album berisi semua foto yang punya tag tertentu, dari folder mana pun. '
              'Tidak ada file yang disalin.',
              style: TextStyle(color: pal.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama album', hintText: 'Anjingku'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tag,
              decoration: const InputDecoration(labelText: 'Tag', hintText: 'Anjing'),
              onSubmitted: (_) => _submit(),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const SectionLabel('Tag yang sudah ada'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in suggestions)
                    TagPill('$t · ${lib.tagCount(t)}', onTap: () {
                      _tag.text = t;
                      if (_name.text.trim().isEmpty) _name.text = t;
                    }),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        FilledButton(onPressed: _submit, child: const Text('Buat album')),
      ],
    );
  }
}

/// Mencari koordinat dari nama tempat.
Future<GeoPlace?> showPlaceSearch(BuildContext context, AppState app, String initial) {
  return showDialog<GeoPlace>(
    context: context,
    builder: (_) => _PlaceSearchDialog(app: app, initial: initial),
  );
}

class _PlaceSearchDialog extends StatefulWidget {
  const _PlaceSearchDialog({required this.app, required this.initial});
  final AppState app;
  final String initial;
  @override
  State<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<_PlaceSearchDialog> {
  late final TextEditingController _q = TextEditingController(text: widget.initial);
  List<GeoPlace>? _results;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initial.trim().isNotEmpty) _search();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.app.geocoder.search(_q.text);
      if (!mounted) return;
      setState(() => _results = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Tidak bisa mencari lokasi. Periksa koneksi internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final results = _results;
    return AlertDialog(
      title: Text('Cari koordinat', style: kSerif.copyWith(fontSize: 26)),
      content: SizedBox(
        width: 480,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nama tempat', hintText: 'Tegallalang, Bali'),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _loading ? null : _search, child: const Text('Cari')),
            ]),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Expanded(
              child: results == null
                  ? const SizedBox.shrink()
                  : results.isEmpty
                      ? Center(child: Text('Tidak ditemukan. Coba nama yang lebih umum.', style: TextStyle(color: pal.muted)))
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (context, i) => const Divider(),
                          itemBuilder: (context, i) {
                            final r = results[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              leading: Icon(Icons.location_on_outlined, color: pal.accent),
                              title: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(formatCoords(r.lat, r.lon), style: TextStyle(color: pal.muted, fontSize: 12)),
                              onTap: () => Navigator.of(context).pop(r),
                            );
                          },
                        ),
            ),
            Text('Data lokasi © kontributor OpenStreetMap', style: TextStyle(fontSize: 11, color: pal.muted)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
      ],
    );
  }
}

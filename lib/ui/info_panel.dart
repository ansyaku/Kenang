import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';
import 'dialogs.dart';
import 'mini_map.dart';

/// Panel kanan untuk satu foto: lihat & edit nama, lokasi, memori, tag.
class InfoPanel extends StatefulWidget {
  const InfoPanel({super.key, required this.app, required this.item});
  final AppState app;
  final PhotoItem item;

  @override
  State<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends State<InfoPanel> {
  bool _editing = false;
  bool _saving = false;
  final _title = TextEditingController();
  final _loc = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _memory = TextEditingController();
  final _tags = TextEditingController();

  @override
  void dispose() {
    for (final c in [_title, _loc, _lat, _lon, _memory, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startEdit() {
    final m = widget.item.meta;
    _title.text = m.title;
    _loc.text = m.locationName;
    _lat.text = m.lat?.toStringAsFixed(6) ?? '';
    _lon.text = m.lon?.toStringAsFixed(6) ?? '';
    _memory.text = m.description;
    _tags.text = m.tags.join(', ');
    setState(() => _editing = true);
  }

  Future<void> _findCoords() async {
    final place = await showPlaceSearch(context, widget.app, _loc.text);
    if (place == null || !mounted) return;
    setState(() {
      _lat.text = place.lat.toStringAsFixed(6);
      _lon.text = place.lon.toStringAsFixed(6);
      if (_loc.text.trim().isEmpty) _loc.text = place.shortName;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final latV = parseCoord(_lat.text), lonV = parseCoord(_lon.text);
    final anyCoord = _lat.text.trim().isNotEmpty || _lon.text.trim().isNotEmpty;
    if (anyCoord && (latV == null || lonV == null || latV.abs() > 90 || lonV.abs() > 180)) {
      showMessage(context, 'Koordinat tidak valid. Isi lintang dan bujur, atau kosongkan keduanya.');
      return;
    }
    final m = widget.item.meta;
    final next = PhotoMeta(
      title: _title.text.trim(),
      description: _memory.text.trim(),
      locationName: _loc.text.trim(),
      lat: latV,
      lon: lonV,
      tags: parseTags(_tags.text),
      takenAt: m.takenAt,
      camera: m.camera,
    );
    setState(() => _saving = true);
    try {
      final n = await widget.app.library.applyChanges(
        {widget.item: next},
        label: 'Edit ${widget.item.fileName}',
      );
      if (!mounted) return;
      setState(() => _editing = false);
      if (n > 0) showSavedSnack(context, widget.app, 'Tersimpan di dalam file foto');
    } catch (e) {
      if (mounted) showMessage(context, 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.pal.surface,
      child: _editing ? _buildEdit(context) : _buildView(context),
    );
  }

  Widget _buildView(BuildContext context) {
    final pal = context.pal;
    final item = widget.item;
    final m = item.meta;
    final date = m.takenAt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      children: [
        const SectionLabel('Nama foto'),
        const SizedBox(height: 6),
        if (m.title.isEmpty)
          Text('Belum ada nama', style: kSerif.copyWith(fontSize: 26, fontStyle: FontStyle.italic, color: pal.muted))
        else
          SelectableText(m.title, style: kSerif.copyWith(fontSize: 30, height: 1.1, color: pal.text)),
        const SizedBox(height: 6),
        Text(
          date != null ? formatDateLong(date) : 'Tanggal foto tidak diketahui',
          style: TextStyle(fontSize: 13, color: pal.muted),
        ),
        const SizedBox(height: 24),
        const SectionLabel('Lokasi'),
        const SizedBox(height: 8),
        if (!m.hasLocation)
          Text('Belum ada lokasi', style: TextStyle(color: pal.muted))
        else
          Row(children: [
            Icon(Icons.location_on_outlined, size: 18, color: pal.accent),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                m.locationName.isNotEmpty ? m.locationName : formatCoords(m.lat!, m.lon!),
                style: const TextStyle(fontSize: 14.5),
              ),
            ),
          ]),
        if (m.hasGps) ...[
          const SizedBox(height: 10),
          MiniMap(lat: m.lat!, lon: m.lon!),
          Row(children: [
            Text(formatCoords(m.lat!, m.lon!), style: TextStyle(fontSize: 11.5, color: pal.muted)),
            const Spacer(),
            TextButton(
              onPressed: () => Process.run('open', [
                'https://maps.apple.com/?ll=${m.lat},${m.lon}&q=${Uri.encodeComponent(m.locationName.isEmpty ? 'Foto' : m.locationName)}',
              ]),
              child: const Text('Buka di Peta'),
            ),
          ]),
        ],
        const SizedBox(height: 22),
        const SectionLabel('Memori'),
        const SizedBox(height: 8),
        if (m.hasMemory)
          SelectableText(m.description, style: kSerif.copyWith(fontSize: 19, height: 1.5, color: pal.text))
        else
          Text('Belum ada memori. Klik "Edit info" untuk menulis.', style: TextStyle(color: pal.muted, height: 1.4)),
        if (m.tags.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionLabel('Tag'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final t in m.tags) TagPill(t)]),
        ],
        const SizedBox(height: 22),
        Text(
          [if (m.camera.isNotEmpty) m.camera, item.fileName].join(' · '),
          style: TextStyle(fontSize: 12, color: pal.muted),
        ),
        const SizedBox(height: 18),
        Row(children: [
          FilledButton.icon(
            onPressed: _startEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit info'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Tampilkan di Finder',
            onPressed: () => Process.run('open', ['-R', item.path]),
            icon: const Icon(Icons.folder_open_outlined),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.check_rounded, size: 14, color: pal.ok),
          const SizedBox(width: 6),
          Text('Info tersimpan di dalam file foto', style: TextStyle(fontSize: 12, color: pal.ok)),
        ]),
      ],
    );
  }

  Widget _buildEdit(BuildContext context) {
    final pal = context.pal;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.escape): () => setState(() => _editing = false),
      },
      child: FocusTraversalGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          children: [
            Text('Edit info', style: kSerif.copyWith(fontSize: 28)),
            const SizedBox(height: 4),
            Text(widget.item.fileName, style: TextStyle(fontSize: 12, color: pal.muted)),
            const SizedBox(height: 18),
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama foto'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _loc,
              decoration: const InputDecoration(labelText: 'Lokasi (nama tempat)'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(controller: _lat, decoration: const InputDecoration(labelText: 'Lintang')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(controller: _lon, decoration: const InputDecoration(labelText: 'Bujur')),
              ),
            ]),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _findCoords,
                icon: const Icon(Icons.travel_explore, size: 18),
                label: const Text('Cari koordinat dari nama tempat'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memory,
              minLines: 5,
              maxLines: 14,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(labelText: 'Memori', alignLabelWithHint: true),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Tag',
                helperText: 'Pisahkan dengan koma. Contoh: Anjing, Mochi, Rumah',
              ),
            ),
            const SizedBox(height: 22),
            Row(children: [
              OutlinedButton(
                onPressed: _saving ? null : () => setState(() => _editing = false),
                child: const Text('Batal'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simpan ke foto  ⌘S'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

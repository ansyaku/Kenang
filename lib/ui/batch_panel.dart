import 'package:flutter/material.dart';

import '../app_state.dart';
import '../batch.dart';
import '../models.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';
import 'dialogs.dart';

/// Panel kanan saat beberapa foto dipilih: isi satu kolom untuk semuanya.
class BatchPanel extends StatefulWidget {
  const BatchPanel({super.key, required this.app, required this.targets});
  final AppState app;
  final List<PhotoItem> targets;

  @override
  State<BatchPanel> createState() => _BatchPanelState();
}

class _BatchPanelState extends State<BatchPanel> {
  bool _doTitle = false, _doLoc = false, _doMemory = false, _doTags = false;
  final _pattern = TextEditingController(text: '{folder} #{nomor}');
  final _loc = TextEditingController();
  final _memory = TextEditingController();
  final _tags = TextEditingController();
  double? _lat, _lon;
  WriteMode _mode = WriteMode.fillEmpty;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_pattern, _loc, _memory, _tags]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_pattern, _loc, _memory, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  BatchRequest get _request => BatchRequest(
        doTitle: _doTitle,
        doLocation: _doLoc,
        doMemory: _doMemory,
        doTags: _doTags,
        titlePattern: _pattern.text,
        locationName: _loc.text,
        lat: _lat,
        lon: _lon,
        memory: _memory.text,
        tags: parseTags(_tags.text),
        mode: _mode,
      );

  void _insertToken(String token) {
    final c = _pattern;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : c.text.length;
    final end = sel.isValid ? sel.end : c.text.length;
    final text = c.text.replaceRange(start, end, token);
    c.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: start + token.length));
    if (!_doTitle) setState(() => _doTitle = true);
  }

  Future<void> _findCoords() async {
    final place = await showPlaceSearch(context, widget.app, _loc.text);
    if (place == null || !mounted) return;
    setState(() {
      _lat = place.lat;
      _lon = place.lon;
      if (_loc.text.trim().isEmpty) _loc.text = place.shortName;
      _doLoc = true;
    });
  }

  Future<void> _apply(Map<PhotoItem, PhotoMeta> changes) async {
    if (_mode == WriteMode.overwrite) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Timpa isian lama?'),
          content: Text('${changes.length} foto akan diganti isiannya. Kamu masih bisa membatalkannya dengan Urungkan.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Timpa')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _applying = true);
    try {
      final n = await widget.app.library.applyChanges(changes, label: 'Edit massal ${changes.length} foto');
      if (mounted) showSavedSnack(context, widget.app, '$n foto diperbarui');
    } catch (e) {
      if (mounted) showMessage(context, 'Sebagian gagal ditulis: $e');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = widget.app.library;
    final targets = widget.targets;
    final req = _request;
    final changes = computeBatch(targets, req);
    final s = summarize(changes);
    final examples = targets.take(2).map((t) => expandPattern(_pattern.text, t, targets.indexOf(t) + 1)).toList();
    String line(int changed) => '$changed diubah · ${targets.length - changed} tetap';

    return Container(
      color: pal.surface,
      child: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
            children: [
              Text('Edit ${targets.length} foto sekaligus', style: kSerif.copyWith(fontSize: 26, height: 1.1)),
              const SizedBox(height: 6),
              Text(
                'Centang kolom yang mau diisi. Kolom yang tidak dicentang tidak diubah.',
                style: TextStyle(fontSize: 13, color: pal.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              _Section(
                label: 'Nama foto',
                value: _doTitle,
                onChanged: (v) => setState(() => _doTitle = v),
                children: [
                  TextField(controller: _pattern, decoration: const InputDecoration(labelText: 'Pola nama')),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final t in ['{nomor}', '{folder}', '{tanggal}', '{berkas}'])
                      TagPill('+ $t', onTap: () => _insertToken(t)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Contoh: ${examples.where((e) => e.isNotEmpty).join(', ')}${targets.length > 2 ? ', …' : ''}',
                    style: TextStyle(fontSize: 12, color: pal.muted),
                  ),
                ],
              ),
              _Section(
                label: 'Lokasi',
                value: _doLoc,
                onChanged: (v) => setState(() => _doLoc = v),
                children: [
                  TextField(controller: _loc, decoration: const InputDecoration(labelText: 'Nama tempat')),
                  const SizedBox(height: 4),
                  Row(children: [
                    TextButton.icon(
                      onPressed: _findCoords,
                      icon: const Icon(Icons.travel_explore, size: 18),
                      label: const Text('Cari koordinat'),
                    ),
                    const Spacer(),
                    if (_lat != null && _lon != null) ...[
                      Text(formatCoords(_lat!, _lon!), style: TextStyle(fontSize: 12, color: pal.ok)),
                      IconButton(
                        tooltip: 'Hapus koordinat',
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          _lat = null;
                          _lon = null;
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ]),
                  if (_lat == null)
                    Text('Tanpa koordinat, GPS foto tidak diubah.', style: TextStyle(fontSize: 12, color: pal.muted)),
                ],
              ),
              _Section(
                label: 'Memori',
                value: _doMemory,
                onChanged: (v) => setState(() => _doMemory = v),
                children: [
                  TextField(
                    controller: _memory,
                    minLines: 3,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(labelText: 'Memori', alignLabelWithHint: true),
                  ),
                ],
              ),
              _Section(
                label: 'Tag',
                value: _doTags,
                onChanged: (v) => setState(() => _doTags = v),
                children: [
                  TextField(
                    controller: _tags,
                    decoration: const InputDecoration(labelText: 'Tag', helperText: 'Pisahkan dengan koma'),
                  ),
                  if (lib.allTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final t in lib.allTags.take(10))
                        TagPill(t, onTap: () {
                          _tags.text = mergeTags(parseTags(_tags.text), [t]).join(', ');
                          setState(() => _doTags = true);
                        }),
                    ]),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              const SectionLabel('Cara menulis'),
              const SizedBox(height: 8),
              _ModeOption(
                selected: _mode == WriteMode.fillEmpty,
                title: 'Isi yang kosong saja',
                subtitle: 'Foto yang sudah terisi dilewati',
                onTap: () => setState(() => _mode = WriteMode.fillEmpty),
              ),
              _ModeOption(
                selected: _mode == WriteMode.overwrite,
                title: 'Timpa semua',
                subtitle: 'Ganti isian lama. Kolom dicentang yang dibiarkan kosong akan dihapus.',
                onTap: () => setState(() => _mode = WriteMode.overwrite),
              ),
              _ModeOption(
                selected: _mode == WriteMode.append,
                title: 'Tambahkan di belakang',
                subtitle: 'Disambung ke isian lama, tag digabung. Lokasi hanya diisi jika kosong.',
                onTap: () => setState(() => _mode = WriteMode.append),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pratinjau', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (!req.anyField)
                      Text('Belum ada kolom yang dicentang.', style: TextStyle(fontSize: 13, color: pal.muted)),
                    if (_doTitle) Text('Nama: ${line(s.title)}', style: const TextStyle(fontSize: 13, height: 1.6)),
                    if (_doLoc) Text('Lokasi: ${line(s.location)}', style: const TextStyle(fontSize: 13, height: 1.6)),
                    if (_doMemory) Text('Memori: ${line(s.memory)}', style: const TextStyle(fontSize: 13, height: 1.6)),
                    if (_doTags) Text('Tag: ${line(s.tags)}', style: const TextStyle(fontSize: 13, height: 1.6)),
                    if (req.anyField)
                      Text('Bisa dibatalkan dengan Urungkan.', style: TextStyle(fontSize: 12, color: pal.muted, height: 1.6)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            OutlinedButton(
              onPressed: _applying ? null : lib.clearSelection,
              child: const Text('Batal'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _applying || changes.isEmpty ? null : () => _apply(changes),
                child: _applying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(changes.isEmpty ? 'Tidak ada perubahan' : 'Terapkan ke ${changes.length} foto'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.value, required this.onChanged, required this.children});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 4, 14, 12),
      decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(!value),
            child: Row(children: [
              Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: value ? pal.text : pal.muted),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Opacity(
              opacity: value ? 1 : 0.55,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({required this.selected, required this.title, required this.subtitle, required this.onTap});
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? pal.accentSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: selected ? pal.accent : pal.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? pal.accent : pal.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: pal.muted, height: 1.35)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

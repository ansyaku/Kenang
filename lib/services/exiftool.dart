import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models.dart';
import 'meta_codec.dart';

class ExifResult {
  ExifResult(this.stdout, this.stderr);
  final String stdout;
  final String stderr;
}

class ExifWriteError implements Exception {
  ExifWriteError(this.message);
  final String message;
  @override
  String toString() => message.isEmpty ? 'ExifTool gagal menulis' : message;
}

/// Satu proses ExifTool yang tetap menyala (-stay_open) supaya cepat.
/// Perintah dijalankan berurutan.
class ExifTool {
  ExifTool(this.executable);

  final String executable;

  Process? _proc;
  final StringBuffer _out = StringBuffer();
  final StringBuffer _err = StringBuffer();
  String? _outMarker;
  String? _errMarker;
  Completer<void>? _outDone;
  Completer<void>? _errDone;
  int _seq = 0;
  Future<void> _tail = Future<void>.value();

  /// Aplikasi yang dibuka dari Finder tidak membawa PATH Terminal,
  /// jadi lokasi umum dicek satu per satu.
  static Future<String?> locate() async {
    const candidates = [
      '/opt/homebrew/bin/exiftool',
      '/usr/local/bin/exiftool',
      '/usr/bin/exiftool',
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    try {
      final r = await Process.run('/bin/zsh', ['-lc', 'command -v exiftool']);
      final path = r.stdout.toString().trim();
      if (r.exitCode == 0 && path.isNotEmpty && await File(path).exists()) return path;
    } catch (_) {}
    return null;
  }

  Future<void> _start() async {
    if (_proc != null) return;
    final proc = await Process.start(executable, ['-stay_open', 'True', '-@', '-']);
    proc.stdin.encoding = utf8;
    proc.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((s) {
      _out.write(s);
      _check();
    });
    proc.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((s) {
      _err.write(s);
      _check();
    });
    unawaited(proc.exitCode.then((code) {
      if (identical(_proc, proc)) _proc = null;
      final od = _outDone;
      if (od != null && !od.isCompleted) od.completeError(StateError('ExifTool berhenti (kode $code)'));
      final ed = _errDone;
      if (ed != null && !ed.isCompleted) ed.complete();
    }));
    _proc = proc;
  }

  void _check() {
    final om = _outMarker, od = _outDone;
    if (om != null && od != null && !od.isCompleted && _out.toString().contains(om)) {
      od.complete();
    }
    final em = _errMarker, ed = _errDone;
    if (em != null && ed != null && !ed.isCompleted && _err.toString().contains(em)) {
      ed.complete();
    }
  }

  Future<ExifResult> run(List<String> args) {
    final c = Completer<ExifResult>();
    _tail = _tail.then((_) async {
      try {
        c.complete(await _run(args));
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  Future<ExifResult> _run(List<String> args) async {
    for (final a in args) {
      if (a.contains('\n') || a.contains('\r')) {
        throw ArgumentError('Argumen ExifTool tidak boleh berisi baris baru');
      }
    }
    await _start();
    final proc = _proc!;
    final seq = ++_seq;
    _out.clear();
    _err.clear();
    final outMarker = '{ready$seq}';
    final errMarker = '{kenang-done-$seq}';
    _outMarker = outMarker;
    _errMarker = errMarker;
    final outDone = _outDone = Completer<void>();
    final errDone = _errDone = Completer<void>();

    final b = StringBuffer();
    for (final a in args) {
      b
        ..write(a)
        ..write('\n');
    }
    b
      ..write('-echo4\n')
      ..write('$errMarker\n')
      ..write('-execute$seq\n');
    proc.stdin.write(b.toString());
    await proc.stdin.flush();

    await outDone.future.timeout(const Duration(minutes: 10));
    await errDone.future.timeout(const Duration(seconds: 30), onTimeout: () {});

    final out = _out.toString();
    final err = _err.toString();
    final oi = out.lastIndexOf(outMarker);
    final ei = err.lastIndexOf(errMarker);
    return ExifResult(oi >= 0 ? out.substring(0, oi) : out, ei >= 0 ? err.substring(0, ei) : err);
  }

  /// Membaca info banyak foto sekaligus. Kunci hasil = path file.
  Future<Map<String, PhotoMeta>> readMeta(List<String> paths) async {
    final res = <String, PhotoMeta>{};
    if (paths.isEmpty) return res;
    final r = await run([
      '-j', '-n', '-G1', '-ec', '-charset', 'iptc=UTF8',
      ...kReadTagArgs,
      ...paths,
    ]);
    final text = r.stdout.trim();
    if (text.isEmpty) return res;
    final list = jsonDecode(text) as List;
    for (final e in list) {
      final m = (e as Map).cast<String, dynamic>();
      final src = m['SourceFile'];
      if (src is String) res[src] = parseExifJson(m);
    }
    return res;
  }

  /// Menulis kolom yang sama ke beberapa file. Data gambar tidak disentuh.
  Future<void> write(List<String> paths, MetaWrite w) async {
    if (w.isEmpty || paths.isEmpty) return;
    final args = <String>['-m', '-overwrite_original_in_place', '-ec'];
    if (w.touchesIptc) {
      args.addAll(['-charset', 'iptc=UTF8', '-IPTC:CodedCharacterSet=UTF8']);
    }
    args
      ..addAll(w.toArgs())
      ..addAll(paths);
    final r = await run(args);
    final all = '${r.stdout}\n${r.stderr}';
    final failed = RegExp(r"(\d+) files? weren't updated due to errors").firstMatch(all);
    if (failed != null && int.parse(failed.group(1)!) > 0) {
      final lines = r.stderr
          .split('\n')
          .where((l) => l.startsWith('Error'))
          .take(3)
          .join('\n');
      throw ExifWriteError(lines.isEmpty ? r.stderr.trim() : lines);
    }
  }

  Future<void> dispose() async {
    final p = _proc;
    if (p == null) return;
    try {
      p.stdin.write('-stay_open\nFalse\n');
      await p.stdin.flush();
    } catch (_) {}
    _proc = null;
  }
}

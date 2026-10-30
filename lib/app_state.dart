import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'library.dart';
import 'services/exiftool.dart';
import 'services/geocoder.dart';
import 'services/settings.dart';
import 'services/thumbs.dart';

class AppState extends ChangeNotifier {
  final settings = Settings();
  final geocoder = Geocoder();
  final homeFocus = FocusNode(debugLabel: 'kenang-home');
  late final Library library;
  late final ThumbService thumbs;

  String? exifPath;
  bool checkingExif = true;
  ExifTool? _exif;

  String get _home => Platform.environment['HOME'] ?? Directory.systemTemp.path;

  Future<void> init() async {
    await settings.load();
    thumbs = ThumbService(p.join(_home, 'Library', 'Caches', 'Kenang'));
    library = Library(supportDir: p.join(_home, 'Library', 'Application Support', 'Kenang'));
    unawaited(detectExif());
  }

  Future<void> detectExif() async {
    checkingExif = true;
    notifyListeners();
    exifPath = await ExifTool.locate();
    if (exifPath != null && _exif == null) {
      _exif = ExifTool(exifPath!);
      library.exif = _exif;
    }
    checkingExif = false;
    notifyListeners();
    final r = settings.rootPath;
    if (_exif != null && library.root == null && r != null && Directory(r).existsSync()) {
      await library.openRoot(r);
    }
  }

  Future<void> pickRoot() async {
    final dir = await getDirectoryPath(confirmButtonText: 'Pilih folder ini');
    if (dir == null) return;
    await settings.setRoot(dir);
    notifyListeners();
    await library.openRoot(dir);
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

/// Gambar foto dari cache thumbnail (atau pratinjau besar).
class Thumb extends StatefulWidget {
  const Thumb({
    super.key,
    required this.app,
    required this.path,
    this.large = false,
    this.fit = BoxFit.cover,
    this.showPlaceholder = true,
  });

  final AppState app;
  final String path;
  final bool large;
  final BoxFit fit;
  final bool showPlaceholder;

  @override
  State<Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<Thumb> {
  late Future<File?> _file;

  @override
  void initState() {
    super.initState();
    _file = _load();
  }

  @override
  void didUpdateWidget(Thumb old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.large != widget.large) _file = _load();
  }

  Future<File?> _load() =>
      widget.large ? widget.app.thumbs.preview(widget.path) : widget.app.thumbs.thumb(widget.path);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snap) {
        final f = snap.data;
        if (f == null) {
          if (!widget.showPlaceholder) return const SizedBox.shrink();
          final failed = snap.connectionState == ConnectionState.done;
          return Container(
            color: pal.placeholder,
            alignment: Alignment.center,
            child: failed ? Icon(Icons.broken_image_outlined, color: pal.muted) : null,
          );
        }
        return Image.file(
          f,
          fit: widget.fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stack) => widget.showPlaceholder
              ? Container(
                  color: pal.placeholder,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: pal.muted),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

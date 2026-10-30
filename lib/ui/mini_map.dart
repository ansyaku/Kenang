import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/geocoder.dart';
import '../theme.dart';

/// Peta kecil dari ubin OpenStreetMap, titik foto di tengah.
class MiniMap extends StatelessWidget {
  const MiniMap({super.key, required this.lat, required this.lon, this.height = 150, this.zoom = 14});

  final double lat;
  final double lon;
  final double height;
  final int zoom;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        decoration: BoxDecoration(color: pal.surface2, border: Border.all(color: pal.border)),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final h = height;
          final n = 1 << zoom;
          final latRad = lat * math.pi / 180;
          final xf = (lon + 180) / 360 * n;
          final yf = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n;
          final px = xf * 256, py = yf * 256;
          final tx0 = xf.floor(), ty0 = yf.floor();
          final tiles = <Widget>[];
          for (var dx = -2; dx <= 2; dx++) {
            for (var dy = -1; dy <= 1; dy++) {
              final tx = tx0 + dx, ty = ty0 + dy;
              if (ty < 0 || ty >= n) continue;
              final left = tx * 256 - px + w / 2;
              final top = ty * 256 - py + h / 2;
              if (left > w || left + 256 < 0 || top > h || top + 256 < 0) continue;
              final wrapped = ((tx % n) + n) % n;
              tiles.add(Positioned(
                left: left,
                top: top,
                width: 256,
                height: 256,
                child: Image.network(
                  'https://tile.openstreetmap.org/$zoom/$wrapped/$ty.png',
                  headers: const {'User-Agent': kUserAgent},
                  fit: BoxFit.fill,
                  errorBuilder: (context, e, s) => const SizedBox.shrink(),
                ),
              ));
            }
          }
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              ...tiles,
              Positioned(
                left: w / 2 - 14,
                top: h / 2 - 30,
                child: Icon(Icons.location_on, size: 30, color: pal.accent, shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ]),
              ),
              Positioned(
                right: 4,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  color: Colors.white.withValues(alpha: 0.75),
                  child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: Colors.black87)),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

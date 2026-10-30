import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

/// Label kecil huruf kapital: "NAMA FOTO", "LOKASI", …
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 11.5, letterSpacing: 0.9, color: context.pal.muted, fontWeight: FontWeight.w500),
      );
}

class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: pal.surface2, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 12.5, color: pal.text)),
    );
    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: pill),
    );
  }
}

/// Tombol bulat di atas foto (panah, putar, kembali).
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.tooltip, this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: onPressed == null ? 0.25 : 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white.withValues(alpha: onPressed == null ? 0.4 : 1), size: 22),
          ),
        ),
      ),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Pesan setelah menyimpan, dengan tombol Urungkan.
void showSavedSnack(BuildContext context, AppState app, String message) {
  final lib = app.library;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      action: lib.canUndo
          ? SnackBarAction(
              label: 'Urungkan',
              onPressed: () async {
                try {
                  await lib.undo();
                  messenger.showSnackBar(const SnackBar(content: Text('Perubahan dibatalkan')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Gagal membatalkan: $e')));
                }
              },
            )
          : null,
    ));
}

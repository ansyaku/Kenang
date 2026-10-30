import 'package:flutter/material.dart';

/// Warna Kenang untuk mode gelap & terang.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.accentSoft,
    required this.ok,
    required this.placeholder,
    required this.viewerBg,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color accentText;
  final Color accentSoft;
  final Color ok;
  final Color placeholder;
  final Color viewerBg;

  static const dark = Palette(
    bg: Color(0xFF15171A),
    surface: Color(0xFF1B1D21),
    surface2: Color(0xFF23262B),
    border: Color(0xFF2A2D32),
    text: Color(0xFFECEAE6),
    muted: Color(0xFFA3A8AE),
    accent: Color(0xFFE8B04B),
    onAccent: Color(0xFF15171A),
    accentText: Color(0xFFF3C873),
    accentSoft: Color(0xFF2A2418),
    ok: Color(0xFF9FC59A),
    placeholder: Color(0xFF2A2D32),
    viewerBg: Color(0xFF0F1113),
  );

  static const light = Palette(
    bg: Color(0xFFF6F4EF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFEBE3),
    border: Color(0xFFE0DACF),
    text: Color(0xFF1C1B19),
    muted: Color(0xFF66625B),
    accent: Color(0xFFE8B04B),
    onAccent: Color(0xFF15171A),
    accentText: Color(0xFF8A5A00),
    accentSoft: Color(0xFFFBF0D9),
    ok: Color(0xFF2F6B2A),
    placeholder: Color(0xFFE5E0D6),
    viewerBg: Color(0xFFECE8E0),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) =>
      (other is Palette && t >= 0.5) ? other : this;
}

const kSerif = TextStyle(
  fontFamily: 'Iowan Old Style',
  fontFamilyFallback: ['Georgia', 'Times New Roman'],
);

extension PaletteContext on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: b).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    surface: p.surface,
    onSurface: p.text,
    outline: p.border,
    outlineVariant: p.border,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c, width: w),
      );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    extensions: [p],
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.bg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border(p.border),
      enabledBorder: border(p.border),
      focusedBorder: border(p.accent, 1.5),
      labelStyle: TextStyle(color: p.muted),
      hintStyle: TextStyle(color: p.muted),
      helperStyle: TextStyle(color: p.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        minimumSize: const Size(0, 44),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        side: BorderSide(color: p.border),
        minimumSize: const Size(0, 40),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.text, shape: shape),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.text),
    ),
    popupMenuTheme: PopupMenuThemeData(color: p.surface),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, width: 420),
    tooltipTheme: TooltipThemeData(waitDuration: const Duration(milliseconds: 500)),
  );
}

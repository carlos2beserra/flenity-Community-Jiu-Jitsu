import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta leve e arejada, com azuis inspirados no novo visual do app.
abstract final class Palette {
  static const mat = Color(0xFFF3F8FC);
  static const mat2 = Color(0xFFEAF3FB);
  static const panel = Color(0xFFFFFFFF);
  static const panel2 = Color(0xFFE7F1FA);
  static const line = Color(0xFFDCE8F2);
  static const ink = Color(0xFF183149);
  static const ink2 = Color(0xFF627A90);
  static const ink3 = Color(0xFF8DA1B3);
  static const blood = Color(0xFF1689EF);
  static const good = Color(0xFF218C70);
  static const warn = Color(0xFFB97917);
  static const bad = Color(0xFFD84F5B);
}

/// Desligado nos testes (sem rede para baixar as fontes).
bool appUseGoogleFonts = true;

ThemeData buildTheme() {
  final googleFonts = appUseGoogleFonts;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Palette.mat,
    colorScheme: const ColorScheme.light(
      primary: Palette.blood,
      onPrimary: Colors.white,
      secondary: Color(0xFF56B8F4),
      surface: Palette.panel,
      onSurface: Palette.ink,
      error: Palette.bad,
      outline: Palette.line,
    ),
  );
  final body = googleFonts
      ? GoogleFonts.archivoTextTheme(base.textTheme)
      : base.textTheme;

  return base.copyWith(
    textTheme: body.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: displayStyle(26),
    ),
    cardTheme: CardThemeData(
      color: Palette.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: const Color(0x143B6D96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Palette.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      elevation: 0,
      height: 68,
      indicatorShape: const CircleBorder(),
      indicatorColor: Palette.blood.withValues(alpha: 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Palette.blood
              : Palette.ink3,
          size: 22,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? Palette.blood
              : Palette.ink3,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.mat2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.blood, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Palette.ink2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.blood,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        side: const BorderSide(color: Palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(color: Palette.ink, fontSize: 14),
      backgroundColor: Palette.panel,
    ),
    dividerTheme: const DividerThemeData(
      color: Palette.line,
      space: 1,
      thickness: 1,
    ),
  );
}

/// Tipografia forte e limpa para títulos e números.
TextStyle displayStyle(double size, {Color color = Palette.ink}) {
  final style = TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.05,
    letterSpacing: -0.5,
  );
  return appUseGoogleFonts ? GoogleFonts.archivo(textStyle: style) : style;
}

TextStyle monoStyle({double size = 12, Color color = Palette.ink3}) =>
    TextStyle(
      fontFamily: 'monospace',
      fontSize: size,
      color: color,
      letterSpacing: 0.6,
    );

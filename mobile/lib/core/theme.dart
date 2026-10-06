import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identitas visual Unismuh Makassar: biru navy & emas.
class AppColors {
  static const navy = Color(0xFF0B1A4A);
  static const primary = Color(0xFF1E40AF);
  static const primaryLight = Color(0xFF3B82F6);
  static const sky = Color(0xFF0EA5E9);
  static const gold = Color(0xFFF5B301);
  static const bg = Color(0xFFF3F5FB);
  static const surface = Colors.white;
  static const text = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFF43F5E);
  static const info = Color(0xFF0EA5E9);

  static const gradPrimary = LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF), Color(0xFF0EA5E9)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const gradGold = LinearGradient(colors: [Color(0xFFF5B301), Color(0xFFF97316)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const gradNavy = LinearGradient(colors: [Color(0xFF0B1A4A), Color(0xFF14307A), Color(0xFF1E40AF)], begin: Alignment.topCenter, end: Alignment.bottomCenter);

  static Color status(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'aktif': case 'lunas': case 'disetujui': case 'selesai': case 'hadir': case 'diterima': case 'lulus': case 'lulus seleksi':
        return success;
      case 'diajukan': case 'menunggu': case 'menunggu verifikasi': case 'pengajuan': case 'baru':
        return warning;
      case 'diproses': case 'diverifikasi': case 'proposal': case 'penelitian': case 'seminar hasil': case 'ujian': case 'revisi': case 'izin':
        return info;
      case 'ditolak': case 'alpa': case 'belum bayar': case 'drop out': case 'tidak lulus':
        return danger;
      default:
        return muted;
    }
  }
}

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: AppColors.text, displayColor: AppColors.text);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary, secondary: AppColors.gold, surface: AppColors.surface),
    textTheme: text,
    appBarTheme: AppBarTheme(backgroundColor: Colors.white, foregroundColor: AppColors.text, elevation: 0, scrolledUnderElevation: 0.5,
        centerTitle: false, titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 19)),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE9ECF5)))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: const Color(0xFFF7F8FC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE3E6F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE3E6F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary, side: const BorderSide(color: Color(0xFFBFD3FE)), minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), side: BorderSide.none),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white, indicatorColor: AppColors.primary.withValues(alpha: .12), height: 68, elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => text.labelSmall?.copyWith(
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFEEF0F6), thickness: 1),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    bottomSheetTheme: const BottomSheetThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), backgroundColor: Colors.white, showDragHandle: true),
  );
}

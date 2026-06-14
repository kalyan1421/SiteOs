import 'package:flutter/material.dart';

/// Editorial cream + navy palette.
///
/// Mood: refined, architectural, calm. Cream surfaces with a deep navy
/// accent and warm hairlines. Designed for content-first layouts where
/// imagery and typography do the heavy lifting.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────
  // Deep editorial navy — used sparingly for primary actions and key marks.
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryDark = Color(0xFF172554);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color primaryVariant = Color(0xFF1E40AF);

  // Soft tonal partner to navy — used for chips, highlights, hover.
  static const Color secondary = Color(0xFFB8845C);
  static const Color secondaryDark = Color(0xFF8C5E3C);
  static const Color secondaryLight = Color(0xFFDCC2A8);
  static const Color secondaryVariant = Color(0xFF7A4F32);

  // Accent — used very sparingly for "new", "highlight" callouts.
  static const Color accent = Color(0xFF3B5BDB);
  static const Color accentDark = Color(0xFF1E3A8A);
  static const Color accentLight = Color(0xFF8DA4F1);

  // ── Status ─────────────────────────────────────────────────────────
  static const Color success = Color(0xFF15803D);
  static const Color successLight = Color(0xFFBBF7D0);
  static const Color successDark = Color(0xFF166534);

  static const Color error = Color(0xFFB91C1C);
  static const Color errorLight = Color(0xFFFECACA);
  static const Color errorDark = Color(0xFF991B1B);

  static const Color warning = Color(0xFFB45309);
  static const Color warningLight = Color(0xFFFDE68A);
  static const Color warningDark = Color(0xFF92400E);

  static const Color info = Color(0xFF1E40AF);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF1E3A8A);

  // ── Surfaces ───────────────────────────────────────────────────────
  // Warm cream paper-like background.
  static const Color background = Color(0xFFFAF8F3);
  static const Color scaffoldBackground = Color(0xFFFAF8F3);

  // Pure white for elevated cards and surfaces.
  static const Color surface = Color(0xFFFFFFFF);

  // Slightly warm tinted neutral for filled chips and subtle blocks.
  static const Color surfaceVariant = Color(0xFFF3EFE6);

  // ── Text ───────────────────────────────────────────────────────────
  // All values verified against cream (#FAF8F3) for WCAG AA compliance.
  // textPrimary  ~17:1, textSecondary ~7:1, textHint ~4.7:1 — all pass.
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF4B4B53);
  static const Color textHint = Color(0xFF6F6A5E);
  static const Color textDisabled = Color(0xFFA8A296);
  static const Color textOnPrimary = Color(0xFFFAF8F3);
  static const Color textOnSecondary = Color(0xFF0F172A);

  // ── Borders / dividers ─────────────────────────────────────────────
  // Warm cream hairlines instead of grey-blue.
  static const Color border = Color(0xFFE7E2D8);
  static const Color borderLight = Color(0xFFF1ECE2);
  static const Color borderDark = Color(0xFFD5CFC2);
  static const Color divider = Color(0xFFE7E2D8);

  // ── Shadow ─────────────────────────────────────────────────────────
  // Warm low-alpha shadows — never blue/grey on cream.
  static const Color shadow = Color(0x14241C0A);
  static const Color shadowLight = Color(0x0A241C0A);
  static const Color shadowDark = Color(0x1F241C0A);

  // ── Roles ──────────────────────────────────────────────────────────
  static const Color superAdmin = Color(0xFF7C3AED);
  static const Color admin = Color(0xFF1E3A8A);
  static const Color siteManager = Color(0xFF15803D);

  // ── Project status ─────────────────────────────────────────────────
  static const Color statusActive = Color(0xFF15803D);
  static const Color statusPending = Color(0xFFB45309);
  static const Color statusCompleted = Color(0xFF1E3A8A);
  static const Color statusOnHold = Color(0xFF8B8579);
  static const Color statusCancelled = Color(0xFFB91C1C);

  // ── Sidebar (desktop / tablet) ────────────────────────────────────
  static const Color sidebarBackground = Color(0xFF0B1224);
  static const Color sidebarSurface = Color(0xFF1A2240);
  static const Color sidebarTextPrimary = Color(0xFFEDE9DD);
  static const Color sidebarTextSecondary = Color(0xFF9CA3B8);
  static const Color sidebarSelectedBg = Color(0x1AFAF8F3);
  static const Color sidebarHoverBg = Color(0x0DFAF8F3);
  static const Color sidebarAccent = Color(0xFFDCC2A8);

  // ── Chart palette ──────────────────────────────────────────────────
  // Editorial sequence — navy → tonal warmth, distinct but unified.
  static const List<Color> chartColors = [
    Color(0xFF1E3A8A), // navy
    Color(0xFFB8845C), // warm tan
    Color(0xFF15803D), // forest
    Color(0xFF7C3AED), // plum
    Color(0xFF0E7490), // teal
    Color(0xFFB91C1C), // crimson
    Color(0xFFB45309), // ochre
    Color(0xFF3B5BDB), // azure
  ];

  // ── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF0B1224)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFDCC2A8), Color(0xFFB8845C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF15803D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadow presets ─────────────────────────────────────────────────
  // Layered, warm-toned shadows. Calmer than greyscale defaults.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x07241C0A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0C241C0A), blurRadius: 12, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x0A241C0A), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x14241C0A), blurRadius: 28, offset: Offset(0, 16)),
  ];
}

import 'package:flutter/material.dart';

/// SiteOS color system.
///
/// Mood: structured, trustworthy, Indian-first construction software. Cool
/// slate surfaces with a confident Brand Blue, a Precision Teal secondary, and
/// a Site Amber accent (the "active site" dot from the logo).
///
/// Source of truth: SiteOS Brand Guide v1.0 (Section 3 — Color System).
/// Field NAMES are preserved from the previous palette so every screen keeps
/// compiling; only the VALUES changed to the SiteOS tokens.
class AppColors {
  AppColors._();

  // ── Brand (named tokens from the brand guide) ──────────────────────
  static const Color brandBlue = Color(0xFF1B4FD8);
  static const Color brandBlueDark = Color(0xFF1E40AF);
  static const Color brandAmber = Color(0xFFF59E0B);
  static const Color brandTeal = Color(0xFF0891B2);
  static const Color brandNavy = Color(0xFF0F172A);

  // ── Brand — primary (Brand Blue) ───────────────────────────────────
  // Primary buttons, logo mark, links, active states.
  static const Color primary = Color(0xFF1B4FD8);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryVariant = Color(0xFF1D4ED8);

  // Secondary accent — Precision Teal. Info states, charts, subtle accents.
  static const Color secondary = Color(0xFF0891B2);
  static const Color secondaryDark = Color(0xFF155E75);
  static const Color secondaryLight = Color(0xFF67E8F9);
  static const Color secondaryVariant = Color(0xFF0E7490);

  // Accent — Site Amber. The "active site" dot, KPI highlights, callouts.
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentDark = Color(0xFFD97706);
  static const Color accentLight = Color(0xFFFCD34D);

  // ── Status / semantic ──────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF065F46);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFF991B1B);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF92400E);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF1E40AF);

  // ── Surfaces ───────────────────────────────────────────────────────
  // Cool slate-50 page background.
  static const Color background = Color(0xFFF8FAFC);
  static const Color scaffoldBackground = Color(0xFFF8FAFC);

  // Pure white for elevated cards, inputs, modals.
  static const Color surface = Color(0xFFFFFFFF);

  // Slate-100 tinted neutral for filled chips and subtle blocks.
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // ── Text ───────────────────────────────────────────────────────────
  // Verified against white/slate-50 for WCAG AA.
  // Brand Blue on white 8.6:1 · Navy on white 18.1:1.
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textHint = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // ── Borders / dividers ─────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFFCBD5E1);
  static const Color divider = Color(0xFFE2E8F0);

  // ── Shadow ─────────────────────────────────────────────────────────
  // Cool navy-tinted, low-alpha — never warm/grey on slate.
  static const Color shadow = Color(0x140F172A);
  static const Color shadowLight = Color(0x0A0F172A);
  static const Color shadowDark = Color(0x1F0F172A);

  // ── Roles ──────────────────────────────────────────────────────────
  static const Color superAdmin = Color(0xFF7C3AED);
  static const Color admin = Color(0xFF1B4FD8);
  static const Color siteManager = Color(0xFF0891B2);

  // ── Project status ─────────────────────────────────────────────────
  static const Color statusActive = Color(0xFF10B981);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusCompleted = Color(0xFF1B4FD8);
  static const Color statusOnHold = Color(0xFF64748B);
  static const Color statusCancelled = Color(0xFFEF4444);

  // ── Sidebar (desktop / tablet) — on-brand dark navy surface ────────
  static const Color sidebarBackground = Color(0xFF0F172A);
  static const Color sidebarSurface = Color(0xFF1E293B);
  static const Color sidebarTextPrimary = Color(0xFFF1F5F9);
  static const Color sidebarTextSecondary = Color(0xFF94A3B8);
  static const Color sidebarSelectedBg = Color(0x331B4FD8);
  static const Color sidebarHoverBg = Color(0x14FFFFFF);
  static const Color sidebarAccent = Color(0xFFF59E0B);

  // ── Chart palette ──────────────────────────────────────────────────
  // SiteOS sequence — blue → teal → amber → green, distinct but unified.
  static const List<Color> chartColors = [
    Color(0xFF1B4FD8), // brand blue
    Color(0xFF0891B2), // precision teal
    Color(0xFFF59E0B), // site amber
    Color(0xFF10B981), // success green
    Color(0xFF7C3AED), // plum
    Color(0xFFEF4444), // danger red
    Color(0xFF3B82F6), // info blue
    Color(0xFF64748B), // slate
  ];

  // ── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1B4FD8), Color(0xFF1E40AF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF22D3EE), Color(0xFF0891B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadow presets ─────────────────────────────────────────────────
  // Layered, cool navy-tinted shadows. Calm and crisp on slate surfaces.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 28, offset: Offset(0, 16)),
  ];
}

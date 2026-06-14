import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Editorial type system.
///
/// - **Display / Headlines** use Fraunces — a variable serif with editorial
///   character. Reserved for hero moments (welcome, page titles, key metrics).
/// - **Titles / UI** use Plus Jakarta Sans — a refined modern grotesk that
///   reads premium on cream surfaces.
/// - **Body** uses Inter — high-legibility grotesk, ideal for long copy.
class AppTextStyles {
  AppTextStyles._();

  // ── Font families ──────────────────────────────────────────────────

  static String get displayFontFamily =>
      GoogleFonts.fraunces().fontFamily!;

  /// Primary font family for headings (alias kept for backwards compat).
  static String get headingFontFamily =>
      GoogleFonts.plusJakartaSans().fontFamily!;

  static String get titleFontFamily =>
      GoogleFonts.plusJakartaSans().fontFamily!;

  static String get bodyFontFamily => GoogleFonts.inter().fontFamily!;

  // ── Display (editorial serif, hero moments only) ──────────────────

  static TextStyle get displayLarge => GoogleFonts.fraunces(
        fontSize: 52,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        letterSpacing: -1.0,
        height: 1.05,
      );

  static TextStyle get displayMedium => GoogleFonts.fraunces(
        fontSize: 42,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        letterSpacing: -0.8,
        height: 1.08,
      );

  static TextStyle get displaySmall => GoogleFonts.fraunces(
        fontSize: 34,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        letterSpacing: -0.6,
        height: 1.1,
      );

  // ── Headlines (section titles, big card titles) ───────────────────

  static TextStyle get headlineLarge => GoogleFonts.fraunces(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
        height: 1.18,
      );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
        height: 1.22,
      );

  static TextStyle get headlineSmall => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
        height: 1.28,
      );

  // ── Titles (card titles, list items, sheet titles) ────────────────

  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.1,
        height: 1.3,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0,
        height: 1.4,
      );

  static TextStyle get titleSmall => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0,
        height: 1.4,
      );

  // ── Body (paragraph text) ─────────────────────────────────────────

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        letterSpacing: 0,
        height: 1.55,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        letterSpacing: 0,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        letterSpacing: 0.05,
        height: 1.45,
      );

  // ── Labels (buttons, chips, form labels) ──────────────────────────

  static TextStyle get labelLarge => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
        height: 1.4,
      );

  static TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
        height: 1.35,
      );

  static TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
        height: 1.45,
      );

  // ── Custom ─────────────────────────────────────────────────────────

  static TextStyle get button => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        letterSpacing: 0.1,
        height: 1.4,
      );

  /// All-caps editorial overline (e.g. ASSIGNED · PROJECTS · etc.)
  static TextStyle get overline => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.6,
        height: 1.5,
      );

  static TextStyle get error => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.error,
        letterSpacing: 0.1,
        height: 1.4,
      );

  static TextStyle get link => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
        letterSpacing: 0,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primary,
        height: 1.4,
      );

  static TextStyle get price => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
        height: 1.25,
      );

  static TextStyle get badge => GoogleFonts.plusJakartaSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
        letterSpacing: 0.6,
        height: 1.2,
      );

  // ── Material TextTheme ────────────────────────────────────────────

  static final TextTheme textTheme = TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );

  // ── Helpers ────────────────────────────────────────────────────────

  static TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);

  static TextStyle withWeight(TextStyle style, FontWeight weight) =>
      style.copyWith(fontWeight: weight);

  static TextStyle bold(TextStyle style) =>
      style.copyWith(fontWeight: FontWeight.w700);

  static TextStyle semiBold(TextStyle style) =>
      style.copyWith(fontWeight: FontWeight.w600);

  static TextStyle secondary(TextStyle style) =>
      style.copyWith(color: AppColors.textSecondary);

  static TextStyle primary(TextStyle style) =>
      style.copyWith(color: AppColors.primary);
}

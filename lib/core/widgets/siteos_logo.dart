import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Background context the SiteOS logo is placed on. Drives the mark colors per
/// the brand guide (Section 2 — Logo on Colored Backgrounds).
enum SiteOsLogoVariant {
  /// On white / light surfaces → Brand Blue square, white S, amber dot.
  color,

  /// On dark (navy) surfaces → translucent white square, white S, amber dot.
  onDark,

  /// On Brand Blue surfaces → translucent white square, white S, amber dot.
  onBrand,
}

/// The SiteOS logo mark — "The Site Quad".
///
/// A rounded square in Brand Blue with a bold white "S" and a small Site Amber
/// dot at the top-right (the single "active site" under control). Optionally
/// renders the "SiteOS" wordmark (Site w600 + OS w800) beside the mark.
class SiteOsLogo extends StatelessWidget {
  /// Edge length of the square mark in logical pixels.
  final double size;

  /// Whether to render the "SiteOS" wordmark next to the mark.
  final bool showWordmark;

  /// Background context — selects the mark color treatment.
  final SiteOsLogoVariant variant;

  /// Optional override for wordmark text color. Defaults per [variant].
  final Color? wordmarkColor;

  const SiteOsLogo({
    super.key,
    this.size = 36,
    this.showWordmark = false,
    this.variant = SiteOsLogoVariant.color,
    this.wordmarkColor,
  });

  Color get _squareColor => switch (variant) {
        SiteOsLogoVariant.color => AppColors.brandBlue,
        SiteOsLogoVariant.onDark => Colors.white.withValues(alpha: 0.12),
        SiteOsLogoVariant.onBrand => Colors.white.withValues(alpha: 0.15),
      };

  Color get _defaultWordmarkColor => switch (variant) {
        SiteOsLogoVariant.color => AppColors.textPrimary,
        SiteOsLogoVariant.onDark => Colors.white,
        SiteOsLogoVariant.onBrand => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rounded square base.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _squareColor,
              borderRadius: BorderRadius.circular(size * 0.22),
            ),
            alignment: Alignment.center,
            child: Text(
              'S',
              style: GoogleFonts.spaceGrotesk(
                fontSize: size * 0.56,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          // Site Amber "active site" dot, top-right.
          Positioned(
            top: size * 0.09,
            right: size * 0.09,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: const BoxDecoration(
                color: AppColors.brandAmber,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );

    if (!showWordmark) return mark;

    final wmColor = wordmarkColor ?? _defaultWordmarkColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Site',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w600,
                  color: wmColor,
                  letterSpacing: -0.3,
                  height: 1,
                ),
              ),
              TextSpan(
                text: 'OS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w800,
                  color: wmColor,
                  letterSpacing: -0.3,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

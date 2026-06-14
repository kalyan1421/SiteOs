import 'package:flutter/material.dart';

/// SiteOS spacing, radius, and elevation tokens.
///
/// Base unit is 8px — all spacing is a multiple of 8 (with a 4px half-step).
/// Source of truth: SiteOS Brand Guide v1.0 (Section 5 — Spacing & Grid).
class AppSpacing {
  AppSpacing._();

  static const double s1 = 4; // tight internal spacing, icon-to-label
  static const double s2 = 8; // default small gap
  static const double s3 = 12; // compact list items
  static const double s4 = 16; // default card padding, form fields
  static const double s5 = 20; // section internal padding
  static const double s6 = 24; // card-to-card gap
  static const double s8 = 32; // section separators
  static const double s10 = 40; // large section padding
  static const double s12 = 48; // hero sections
  static const double s16 = 64; // between major page sections
}

/// Border-radius tokens.
class AppRadius {
  AppRadius._();

  static const double sm = 4; // badges, chips, small tags
  static const double md = 8; // buttons, inputs, small cards
  static const double lg = 12; // cards, modals, dropdowns
  static const double xl = 16; // dashboard panels, bottom sheets
  static const double full = 9999; // pills, avatar circles

  static const Radius smR = Radius.circular(sm);
  static const Radius mdR = Radius.circular(md);
  static const Radius lgR = Radius.circular(lg);
  static const Radius xlR = Radius.circular(xl);
}

/// Elevation / shadow tokens (cool navy-tinted, low alpha).
class AppElevation {
  AppElevation._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x120F172A), blurRadius: 6, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 15, offset: Offset(0, 10)),
  ];
}

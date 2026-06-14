import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';

/// Indian-grouping ₹ formatter shared across the BOQ module.
/// e.g. 1234567.5 -> "₹12,34,567.50". Self-contained (no core/util deps).
class BoqMoney {
  BoqMoney._();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _qty = NumberFormat.decimalPattern('en_IN');

  /// Format a ₹ amount with Indian digit grouping.
  static String amount(num value) => _inr.format(value);

  /// Format a quantity (up to 3 decimals, trailing zeros trimmed).
  static String qty(num value) {
    final s = value.toStringAsFixed(3);
    final trimmed = s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
    // Re-group the integer part for readability.
    final parts = trimmed.split('.');
    final grouped = _qty.format(int.tryParse(parts[0]) ?? 0);
    return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  }
}

/// A ₹ amount rendered in JetBrains Mono (per the SiteOS brand guide).
class BoqMoneyText extends StatelessWidget {
  final num value;
  final TextStyle? baseStyle;
  final Color? color;
  final FontWeight? weight;
  final TextAlign? textAlign;

  const BoqMoneyText(
    this.value, {
    super.key,
    this.baseStyle,
    this.color,
    this.weight,
    this.textAlign,
  });

  /// Larger, emphasised variant for grand totals.
  const BoqMoneyText.large(
    this.value, {
    super.key,
    this.color,
    this.weight = FontWeight.w700,
    this.textAlign,
  }) : baseStyle = null;

  @override
  Widget build(BuildContext context) {
    final style = (baseStyle ?? AppTextStyles.mono).copyWith(
      color: color ?? AppColors.textPrimary,
      fontWeight: weight,
    );
    return Text(
      BoqMoney.amount(value),
      style: style,
      textAlign: textAlign,
    );
  }
}

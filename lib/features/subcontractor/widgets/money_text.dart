import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';

/// Indian-grouping ₹ formatter (e.g. ₹12,34,567.00). Shared by every
/// subcontractor screen so money always renders in JetBrains Mono.
final NumberFormat kInrFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// Formats [value] as an INR string (no widget). Useful in rich-text rows.
String formatInr(num value) => kInrFormat.format(value);

/// A ₹ amount rendered in mono. Use [large] for the primary figure on a card
/// (uses AppTextStyles.price) and the default for inline/table amounts
/// (AppTextStyles.mono).
class MoneyText extends StatelessWidget {
  final num value;
  final bool large;
  final Color? color;
  final TextAlign? textAlign;

  const MoneyText(
    this.value, {
    super.key,
    this.large = false,
    this.color,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final base = large ? AppTextStyles.price : AppTextStyles.mono;
    return Text(
      kInrFormat.format(value),
      textAlign: textAlign,
      style: base.copyWith(color: color ?? AppColors.textPrimary),
    );
  }
}

/// A small labelled row: label on the left, mono ₹ amount on the right.
/// Used in the deduction breakdown card.
class MoneyRow extends StatelessWidget {
  final String label;
  final num value;
  final bool emphasize;
  final Color? amountColor;

  const MoneyRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasize
        ? AppTextStyles.titleSmall
        : AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary);
    final amountStyle = (emphasize ? AppTextStyles.price : AppTextStyles.mono)
        .copyWith(
      color: amountColor ?? AppColors.textPrimary,
      fontSize: emphasize ? 18 : null,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: Text(label, style: labelStyle)),
        const SizedBox(width: 12),
        Text(kInrFormat.format(value), style: amountStyle),
      ],
    );
  }
}

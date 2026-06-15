import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/ra_bill.dart';

/// ₹ formatter for the RA-billing module (Indian grouping, 2 dp).
final NumberFormat kInr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

String formatInr(double value) => kInr.format(value);

/// A right-aligned amount rendered in JetBrains Mono (brand rule for money).
class MoneyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final Color? color;

  const MoneyText(this.amount, {super.key, this.style, this.color});

  @override
  Widget build(BuildContext context) {
    final base = style ?? AppTextStyles.mono;
    return Text(
      formatInr(amount),
      style: color != null ? base.copyWith(color: color) : base,
      textAlign: TextAlign.right,
    );
  }
}

/// A label + mono amount in a single row, used in breakdown lists.
class AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool emphasize;
  final bool negative;

  const AmountRow({
    super.key,
    required this.label,
    required this.amount,
    this.emphasize = false,
    this.negative = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasize
        ? AppTextStyles.titleSmall
        : AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary);
    final amountStyle = (emphasize ? AppTextStyles.price : AppTextStyles.mono)
        .copyWith(
      color: negative
          ? AppColors.error
          : (emphasize ? AppColors.primary : AppColors.textPrimary),
      fontWeight: emphasize ? FontWeight.w600 : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1 + 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: AppSpacing.s4),
          Text(
            '${negative ? '− ' : ''}${formatInr(amount)}',
            style: amountStyle,
          ),
        ],
      ),
    );
  }
}

/// A pill showing the RA bill status with its semantic color.
class StatusBadge extends StatelessWidget {
  final RaBillStatus status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: status.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Standard empty-state column for lists.
class BillingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const BillingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.s4),
            Text(title,
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s2),
            Text(
              message,
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.s5),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Generic error column with retry.
class BillingErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const BillingErrorState({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.error),
            const SizedBox(height: AppSpacing.s4),
            Text(
              l10n.somethingWentWrong,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              '$error',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

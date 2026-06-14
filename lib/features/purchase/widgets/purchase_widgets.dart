import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/purchase_indent.dart';
import '../data/models/purchase_order.dart';

/// Shared formatter for ₹ amounts used across the purchase module.
class PurchaseFormat {
  PurchaseFormat._();

  static final NumberFormat _rupee =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static final NumberFormat _qty = NumberFormat('#,##0.###', 'en_IN');

  /// e.g. ₹1,23,456.00
  static String money(num value) => _rupee.format(value);

  /// e.g. 1,250.5
  static String qty(num value) => _qty.format(value);

  static String date(DateTime? d) =>
      d == null ? '—' : DateFormat('dd MMM yyyy').format(d);
}

/// A small status pill used for both indent and PO statuses.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  factory StatusChip.indent(IndentStatus status) {
    final color = switch (status) {
      IndentStatus.draft => AppColors.textHint,
      IndentStatus.submitted => AppColors.info,
      IndentStatus.approved => AppColors.success,
      IndentStatus.rejected => AppColors.error,
      IndentStatus.closed => AppColors.statusCompleted,
    };
    return StatusChip(label: status.label, color: color);
  }

  factory StatusChip.po(PoStatus status) {
    final color = switch (status) {
      PoStatus.draft => AppColors.textHint,
      PoStatus.approved => AppColors.info,
      PoStatus.received => AppColors.success,
      PoStatus.cancelled => AppColors.error,
    };
    return StatusChip(label: status.label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Standard empty state for purchase lists.
class PurchaseEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PurchaseEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.s4),
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.s2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.s5),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A reusable labelled row showing a value (right-aligned, optionally mono).
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = (mono ? AppTextStyles.mono : AppTextStyles.bodyMedium)
        .copyWith(color: valueColor);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          const SizedBox(width: AppSpacing.s3),
          Flexible(
            child: Text(value, style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

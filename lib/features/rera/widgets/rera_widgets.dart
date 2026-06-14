import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/rera_report.dart';

/// Shared INR formatter for the RERA feature (₹ + Indian grouping).
final NumberFormat reraInr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Format a money amount with the ₹ symbol and Indian digit grouping.
String formatReraInr(double v) => reraInr.format(v);

/// Small status pill for a [ReraReportStatus].
class ReraStatusChip extends StatelessWidget {
  final ReraReportStatus status;
  const ReraStatusChip({super.key, required this.status});

  Color get _bg => switch (status) {
        ReraReportStatus.draft => AppColors.surfaceVariant,
        ReraReportStatus.submitted => AppColors.warningLight,
        ReraReportStatus.approved => AppColors.successLight,
      };

  Color get _fg => switch (status) {
        ReraReportStatus.draft => AppColors.textHint,
        ReraReportStatus.submitted => AppColors.warningDark,
        ReraReportStatus.approved => AppColors.successDark,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: _fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A small labelled metric tile used on the dashboard summary row.
class ReraStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool mono;

  const ReraStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            value,
            style: (mono ? AppTextStyles.price : AppTextStyles.headlineSmall)
                .copyWith(fontSize: 18),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Thin completion progress bar with the percentage label.
class ReraProgressBar extends StatelessWidget {
  final double pct;
  const ReraProgressBar({super.key, required this.pct});

  @override
  Widget build(BuildContext context) {
    final clamped = (pct.clamp(0, 100)) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Completion',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
            Text('${pct.toStringAsFixed(1)}%',
                style: AppTextStyles.mono
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: clamped.toDouble(),
            minHeight: 8,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

/// Generic empty / error placeholder used across the RERA screens.
class ReraPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const ReraPlaceholder({
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
            Icon(icon, size: 44, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.s4),
            Text(title,
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s2),
            Text(
              message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
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

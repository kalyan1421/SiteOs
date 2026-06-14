import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';

/// A small read-only status pill used across the client portal for project
/// statuses and bill statuses. Color is derived from the [status] keyword.
class ClientStatusChip extends StatelessWidget {
  final String status;
  final String label;

  const ClientStatusChip({
    super.key,
    required this.status,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colorsFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color) _colorsFor(String status) {
    switch (status) {
      case 'completed':
      case 'paid':
      case 'approved':
        return (AppColors.successDark, AppColors.successLight);
      case 'in_progress':
        return (AppColors.primaryDark, AppColors.infoLight);
      case 'pending':
      case 'planning':
      case 'on_hold':
        return (AppColors.warningDark, AppColors.warningLight);
      case 'rejected':
      case 'cancelled':
        return (AppColors.errorDark, AppColors.errorLight);
      default:
        return (AppColors.textSecondary, AppColors.surfaceVariant);
    }
  }
}

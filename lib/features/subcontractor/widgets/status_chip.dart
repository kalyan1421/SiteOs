import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/work_order_model.dart';
import '../data/models/sub_ra_bill_model.dart';

/// A compact pill showing a label tinted by a semantic color.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  factory StatusChip.workOrder(WorkOrderStatus status) {
    final color = switch (status) {
      WorkOrderStatus.active => AppColors.statusActive,
      WorkOrderStatus.onHold => AppColors.statusOnHold,
      WorkOrderStatus.completed => AppColors.statusCompleted,
      WorkOrderStatus.cancelled => AppColors.statusCancelled,
    };
    return StatusChip(label: status.label, color: color);
  }

  factory StatusChip.raBill(SubRaBillStatus status) {
    final color = switch (status) {
      SubRaBillStatus.draft => AppColors.statusOnHold,
      SubRaBillStatus.submitted => AppColors.statusPending,
      SubRaBillStatus.approved => AppColors.statusCompleted,
      SubRaBillStatus.paid => AppColors.statusActive,
    };
    return StatusChip(label: status.label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

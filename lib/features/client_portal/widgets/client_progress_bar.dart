import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';

/// A labelled completion progress bar (0–100%) used on client project views.
class ClientProgressBar extends StatelessWidget {
  /// 0.0 – 1.0
  final double fraction;
  final bool showLabel;

  const ClientProgressBar({
    super.key,
    required this.fraction,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Completion', style: AppTextStyles.labelMedium),
              Text(
                '$pct%',
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 10,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              pct >= 100 ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

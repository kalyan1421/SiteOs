import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';

/// A small "Powered by Gemini AI" / indicative-estimate disclaimer banner.
class AiDisclaimerBanner extends StatelessWidget {
  final String text;
  final IconData icon;

  const AiDisclaimerBanner({
    super.key,
    this.text = 'AI-generated. Review before sharing or using.',
    this.icon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard centered error state with a retry action.
class AiErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AiErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 40),
            const SizedBox(height: AppSpacing.s4),
            Text(
              message,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s4),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

/// A full-screen "thinking" indicator with a label, used while AI runs.
class AiBusyOverlay extends StatelessWidget {
  final String label;
  const AiBusyOverlay({super.key, this.label = 'Working…'});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffoldBackground.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.s4),
            Text(label, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// A language toggle chip group (English / हिन्दी).
class AiLanguageToggle extends StatelessWidget {
  final String value; // 'en' | 'hi'
  final ValueChanged<String> onChanged;

  const AiLanguageToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'en', label: Text('English')),
        ButtonSegment(value: 'hi', label: Text('हिन्दी')),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// A labelled tile that summarizes a parsed field (vendor, total, etc).
class AiFieldTile extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const AiFieldTile({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.labelSmall),
          const SizedBox(height: AppSpacing.s1),
          Text(
            value,
            style: mono
                ? AppTextStyles.bodyLarge.copyWith(
                    fontFamily: AppTextStyles.monoFontFamily,
                    fontWeight: FontWeight.w600,
                  )
                : AppTextStyles.bodyLarge,
          ),
        ],
      ),
    );
  }
}

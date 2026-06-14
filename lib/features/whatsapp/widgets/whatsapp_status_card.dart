import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/whatsapp_config.dart';

/// Connection-status banner at the top of the WhatsApp settings screen.
/// Shows whether the company's WhatsApp Cloud API integration is live.
class WhatsAppStatusCard extends StatelessWidget {
  final WhatsAppConfig config;

  const WhatsAppStatusCard({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final connected = config.configured;
    final accent = connected ? AppColors.success : AppColors.warning;
    final bg = connected ? AppColors.successLight : AppColors.warningLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            connected
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: accent,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'WhatsApp connected' : 'WhatsApp not connected',
                  style: AppTextStyles.titleSmall,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  connected
                      ? (config.displayPhone != null
                          ? 'Sending from ${config.displayPhone}'
                          : 'Your WhatsApp Business number is ready to send reports.')
                      : 'Ask your administrator to connect a WhatsApp Business '
                          'number before enabling daily reports.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/siteos_logo.dart';

// StatelessWidget — no logic needed here; routing is handled elsewhere.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SiteOsLogo(size: 96, variant: SiteOsLogoVariant.onBrand),
            const SizedBox(height: 28),
            Text(
              'SiteOS',
              style: AppTextStyles.displaySmall.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Every site. Under control.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

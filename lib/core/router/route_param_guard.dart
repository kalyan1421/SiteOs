import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Validates a path parameter (typically a UUID) before delegating to a
/// screen builder. If the parameter is missing or malformed we short-
/// circuit with an editorial error screen instead of forwarding garbage
/// to the data layer (which would surface as a confusing 4xx/5xx).
///
/// Usage in router:
/// ```dart
/// builder: (context, state) => RouteParamGuard.uuid(
///   state.pathParameters['id'],
///   (id) => ProjectDetailScreen(projectId: id),
/// ),
/// ```
class RouteParamGuard {
  RouteParamGuard._();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Validate a UUID-shaped path parameter and build the screen if it
  /// passes. Returns an [InvalidRouteParamScreen] otherwise.
  static Widget uuid(
    String? rawValue,
    Widget Function(String value) builder, {
    String label = 'ID',
  }) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) {
      return InvalidRouteParamScreen(
        label: label,
        reason: 'No $label was provided.',
      );
    }
    if (!_uuidRegex.hasMatch(value)) {
      return InvalidRouteParamScreen(
        label: label,
        reason: 'The $label "$value" is not in a valid format.',
      );
    }
    return builder(value);
  }

  /// Validate a non-empty string path parameter (no UUID format check).
  static Widget nonEmpty(
    String? rawValue,
    Widget Function(String value) builder, {
    String label = 'value',
  }) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) {
      return InvalidRouteParamScreen(
        label: label,
        reason: 'Missing required $label.',
      );
    }
    return builder(value);
  }
}

/// Friendly error screen for malformed or missing route parameters.
class InvalidRouteParamScreen extends StatelessWidget {
  final String label;
  final String reason;

  const InvalidRouteParamScreen({
    super.key,
    required this.label,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _goHome(context),
        ),
        title: Text(
          'Page unavailable',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.link_off_rounded,
                      size: 28,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'We couldn\'t open this $label',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _goHome(context),
                    child: const Text('Back to dashboard'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goHome(BuildContext context) {
    // Prefer the platform back stack; fall back to /admin/dashboard.
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go('/admin/dashboard');
    }
  }
}

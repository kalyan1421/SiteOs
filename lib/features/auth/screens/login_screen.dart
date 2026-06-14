import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/shake_transition.dart';
import '../../../core/widgets/siteos_logo.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeTransitionState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final authState = ref.read(authProvider);
    if (authState.isLoading) return;

    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }

    try {
      await ref.read(authProvider.notifier).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      final role = ref.read(authProvider).role;
      switch (role) {
        case UserRole.superAdmin:
          context.go('/super-admin/dashboard');
        case UserRole.admin:
          context.go('/admin/dashboard');
        case UserRole.siteManager:
          context.go('/site-manager/dashboard');
        case UserRole.client:
          context.go('/client/dashboard');
        case null:
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _shakeKey.currentState?.shake();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final r = R(Size(constraints.maxWidth, constraints.maxHeight));

              return Stack(
                children: [
                  SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          r.isTablet ? 40 : 24,
                          24,
                          r.isTablet ? 40 : 24,
                          24,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 440),
                            child: ShakeTransition(
                              key: _shakeKey,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  // ── Top: brand + editorial hero ──
                                  _BrandLockup(),
                                  SizedBox(height: r.isTablet ? 56 : 44),
                                  _EditorialHero(
                                    overline: 'Civil · Management',
                                    title: 'Welcome\nback.',
                                    subtitle:
                                        'Sign in to keep your projects, '
                                        'crew and materials moving.',
                                  ),
                                  const SizedBox(height: 36),

                                  // ── Form card ──
                                  Form(
                                    key: _formKey,
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 24, 20, 20),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          // Error banner
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            child: authState.error != null
                                                ? Padding(
                                                    padding:
                                                        const EdgeInsets
                                                            .only(
                                                                bottom: 16),
                                                    child:
                                                        InlineErrorWidget(
                                                      message:
                                                          authState.error!,
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),

                                          _FieldLabel('Email'),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.next,
                                            enabled: !isLoading,
                                            onChanged: (_) {
                                              if (authState.error != null) {
                                                ref
                                                    .read(authProvider
                                                        .notifier)
                                                    .clearError();
                                              }
                                            },
                                            onFieldSubmitted: (_) =>
                                                _passwordFocusNode
                                                    .requestFocus(),
                                            decoration: InputDecoration(
                                              hintText: 'you@company.com',
                                              prefixIcon: const Icon(
                                                Icons.mail_outline_rounded,
                                                size: 19,
                                              ),
                                              prefixIconConstraints:
                                                  const BoxConstraints(
                                                minWidth: 44,
                                                minHeight: 44,
                                              ),
                                            ),
                                            validator: (v) {
                                              if (v == null ||
                                                  v.trim().isEmpty) {
                                                return 'Email is required';
                                              }
                                              if (!v.contains('@')) {
                                                return 'Enter a valid email';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 18),

                                          _FieldLabel('Password'),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _passwordController,
                                            focusNode: _passwordFocusNode,
                                            obscureText: !_isPasswordVisible,
                                            textInputAction:
                                                TextInputAction.done,
                                            enabled: !isLoading,
                                            onFieldSubmitted: (_) =>
                                                _handleLogin(),
                                            onChanged: (_) {
                                              if (authState.error != null) {
                                                ref
                                                    .read(authProvider
                                                        .notifier)
                                                    .clearError();
                                              }
                                            },
                                            decoration: InputDecoration(
                                              hintText: 'Enter your password',
                                              prefixIcon: const Icon(
                                                Icons.lock_outline_rounded,
                                                size: 19,
                                              ),
                                              prefixIconConstraints:
                                                  const BoxConstraints(
                                                minWidth: 44,
                                                minHeight: 44,
                                              ),
                                              suffixIcon: IconButton(
                                                splashRadius: 20,
                                                icon: Icon(
                                                  _isPasswordVisible
                                                      ? Icons
                                                          .visibility_off_outlined
                                                      : Icons
                                                          .visibility_outlined,
                                                  size: 19,
                                                  color: AppColors
                                                      .textSecondary,
                                                ),
                                                onPressed: () => setState(
                                                  () => _isPasswordVisible =
                                                      !_isPasswordVisible,
                                                ),
                                              ),
                                            ),
                                            validator: (v) {
                                              if (v == null || v.isEmpty) {
                                                return 'Password is required';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 6),

                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: isLoading
                                                  ? null
                                                  : () => context.go(
                                                      '/forgot-password'),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal: 4,
                                                  vertical: 6,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text(
                                                  'Forgot password?'),
                                            ),
                                          ),
                                          const SizedBox(height: 14),

                                          // Sign-in CTA
                                          Hero(
                                            tag: 'auth_button',
                                            child: SizedBox(
                                              height: 56,
                                              child: ElevatedButton(
                                                onPressed: isLoading
                                                    ? null
                                                    : _handleLogin,
                                                child: isLoading
                                                    ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors
                                                              .white,
                                                        ),
                                                      )
                                                    : Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: const [
                                                          Text('Sign in'),
                                                          SizedBox(width: 8),
                                                          Icon(
                                                            Icons
                                                                .arrow_forward_rounded,
                                                            size: 18,
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // ── Create company account ──
                                  Center(
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'New to SiteOS?',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: isLoading
                                              ? null
                                              : () => context.go('/register'),
                                          child: const Text(
                                              'Create a company account'),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Footer ──
                                  Center(
                                    child: Text(
                                      '© ${DateTime.now().year}  SiteOS',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: AppColors.textHint,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Loading overlay ──
                  if (isLoading)
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: isLoading ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          color: AppColors.scaffoldBackground
                              .withValues(alpha: 0.78),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppColors.elevatedShadow,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    authState.statusMessage ??
                                        'Signing you in…',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Please don\'t close the app',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Brand lockup — wordmark + tiny accent dot.
// ─────────────────────────────────────────────────────────────────────

class _BrandLockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SiteOsLogo(size: 36, showWordmark: true);
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Editorial hero — overline, serif title, body.
// ─────────────────────────────────────────────────────────────────────

class _EditorialHero extends StatelessWidget {
  final String overline;
  final String title;
  final String subtitle;

  const _EditorialHero({
    required this.overline,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryDark,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: GoogleFonts.fraunces(
            fontSize: 48,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
            letterSpacing: -1.6,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }
}

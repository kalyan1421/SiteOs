import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/siteos_logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../company/providers/company_provider.dart';
import '../providers/auth_provider.dart';

/// Self-service company registration → starts a 14-day free trial.
///
/// Flow (Linear AKS-65): sign up the admin → atomically create the company and
/// promote the profile to `admin` via the `register_company` RPC → refresh the
/// session so the app routes into the admin dashboard.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _gstin = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _company.dispose();
    _gstin.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authProvider.notifier);

      // 1. Create the admin auth user (+ trigger-created profile).
      await auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
      );

      // If email confirmation is required, there's no session yet — finish
      // company setup after the user confirms and signs in.
      if (!SupabaseConfig.isAuthenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "We've emailed you a confirmation link. Confirm it, then sign in "
              'to finish setting up your company.',
            ),
          ),
        );
        context.go('/login');
        return;
      }

      // 2. Atomically create the company + promote to admin.
      await ref.read(companyRepositoryProvider).registerCompany(
            name: _company.text.trim(),
            gstin: _gstin.text.trim(),
            fullName: _fullName.text.trim(),
          );

      // 3. Reload the profile so role=admin + company_id are reflected.
      await auth.refreshSession();

      if (!mounted) return;
      context.go('/admin/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
        title: Text(AppLocalizations.of(context)!.createAccount),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: SiteOsLogo(size: 44, showWordmark: true)),
                    const SizedBox(height: AppSpacing.s6),
                    Text(AppLocalizations.of(context)!.startYourFreeTrial, style: AppTextStyles.headlineMedium),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      '14 days free. No credit card. Every site, under control.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.s6),

                    _field(
                      controller: _company,
                      label: 'Company name',
                      hint: 'e.g. Whitefield Builders',
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your company name'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    _field(
                      controller: _gstin,
                      label: 'GSTIN (optional)',
                      hint: '29AABCT1332L1ZH',
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return v.trim().length == 15
                            ? null
                            : 'GSTIN must be 15 characters';
                      },
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    _field(
                      controller: _fullName,
                      label: 'Your name',
                      hint: 'Full name',
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    _field(
                      controller: _email,
                      label: 'Work email',
                      hint: 'you@company.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter your email';
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(value);
                        return ok ? null : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    _field(
                      controller: _password,
                      label: 'Password',
                      hint: 'At least 8 characters',
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'Use at least 8 characters'
                          : null,
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(_error!, style: AppTextStyles.error),
                    ],

                    const SizedBox(height: AppSpacing.s6),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(AppLocalizations.of(context)!.startFreeTrial),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Center(
                      child: TextButton(
                        onPressed:
                            _isLoading ? null : () => context.go('/login'),
                        child: Text(AppLocalizations.of(context)!.alreadyHaveAccount),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.s2),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          enabled: !_isLoading,
          decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          validator: validator,
        ),
      ],
    );
  }
}

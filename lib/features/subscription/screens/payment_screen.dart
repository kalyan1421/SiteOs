import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/plan.dart';
import '../data/repositories/subscription_repository.dart';
import '../providers/plan_provider.dart';
import '../providers/subscription_provider.dart';

/// Razorpay checkout for a chosen [planKey] (AKS-66).
///
/// We never hold the Razorpay secret: this screen asks the
/// `razorpay-create-subscription` edge function to create the subscription
/// server-side, then hands the returned subscription id to the Razorpay SDK.
/// The plan only flips to active once the verified webhook fires, so on success
/// we invalidate the plan providers and tell the user activation is in progress.
class PaymentScreen extends ConsumerStatefulWidget {
  final String planKey;
  const PaymentScreen({super.key, required this.planKey});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late final Razorpay _razorpay;
  late final SiteOsPlan _plan;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _plan = SiteOsPlan.fromKey(widget.planKey);
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    setState(() => _busy = true);
    try {
      final checkout = await ref
          .read(subscriptionRepositoryProvider)
          .createCheckout(_plan);

      final options = {
        'key': checkout.keyId,
        'subscription_id': checkout.rpSubId,
        'name': 'SiteOS',
        'description': '${_plan.label} plan',
        'prefill': {
          'email': supabase.auth.currentUser?.email ?? '',
        },
        'theme': {'color': '#1B4FD8'},
      };
      _razorpay.open(options);
    } on SubscriptionException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onSuccess(PaymentSuccessResponse response) {
    // Plan activation happens server-side via the webhook. Refresh the cached
    // plan/subscription so the UI reflects it once the webhook lands.
    ref.invalidate(planFeaturesProvider);
    ref.invalidate(currentSubscriptionProvider);
    ref.invalidate(invoicesProvider);
    if (!mounted) return;
    _snack(AppLocalizations.of(context)!.paymentSuccessActivating);
    Navigator.of(context).pop(true);
  }

  void _onError(PaymentFailureResponse response) {
    if (!mounted) return;
    final cancelled = response.code == Razorpay.PAYMENT_CANCELLED;
    _snack(cancelled
        ? AppLocalizations.of(context)!.paymentCancelled
        : AppLocalizations.of(context)!.paymentFailed);
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    _snack('${response.walletName ?? 'Wallet'} selected');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: Text(l10n.checkout)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s5),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.orderSummary,
                            style: AppTextStyles.titleMedium),
                        const SizedBox(height: AppSpacing.s4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_plan.label} ${l10n.plan}',
                                style: AppTextStyles.bodyLarge),
                            Text('₹${_plan.monthlyPrice} ${l10n.perMonth}',
                                style: AppTextStyles.bodyLarge),
                          ],
                        ),
                        const Divider(height: AppSpacing.s6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.dueToday,
                                style: AppTextStyles.titleMedium),
                            Text('₹${_plan.monthlyPrice}',
                                style: AppTextStyles.price),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 16, color: AppColors.textHint),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: Text(l10n.securePaymentNote,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textHint)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _startCheckout,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: AppColors.textOnPrimary),
                            )
                          : Text('${l10n.payWithRazorpay} · '
                              '₹${_plan.monthlyPrice}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

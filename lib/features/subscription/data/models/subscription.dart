/// Razorpay subscription + invoice models (AKS-66).
///
/// Read-only mirrors of the `subscriptions` and `subscription_invoices` tables
/// (migration 064). Both are written ONLY by the razorpay-webhook edge
/// function; the app reads them under RLS to show the billing screens.
library;

import '../models/plan.dart';

/// One Razorpay subscription for the current company.
class Subscription {
  final String id;
  final String? rpSubId;
  final SiteOsPlan plan;
  final String status;
  final DateTime? periodEnd;
  final double? amount;
  final String currency;
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.rpSubId,
    required this.plan,
    required this.status,
    required this.periodEnd,
    required this.amount,
    required this.currency,
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        rpSubId: json['rp_sub_id'] as String?,
        plan: SiteOsPlan.fromKey(json['plan_id'] as String?),
        status: json['status'] as String? ?? 'created',
        periodEnd: json['period_end'] == null
            ? null
            : DateTime.tryParse(json['period_end'] as String),
        amount: (json['amount'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'INR',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// A single successful charge — one row in the billing-history list.
class SubscriptionInvoice {
  final String id;
  final String? rpPaymentId;
  final double amount;
  final String currency;
  final String status;
  final DateTime paidAt;

  const SubscriptionInvoice({
    required this.id,
    required this.rpPaymentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paidAt,
  });

  factory SubscriptionInvoice.fromJson(Map<String, dynamic> json) =>
      SubscriptionInvoice(
        id: json['id'] as String,
        rpPaymentId: json['rp_payment_id'] as String?,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'INR',
        status: json['status'] as String? ?? 'paid',
        paidAt: DateTime.tryParse(json['paid_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Result of starting a subscription on the server — everything the Razorpay
/// checkout needs. Returned by `razorpay-create-subscription`.
class SubscriptionCheckout {
  final String rpSubId;
  final String keyId;
  final double amount;
  final String currency;
  final SiteOsPlan plan;

  const SubscriptionCheckout({
    required this.rpSubId,
    required this.keyId,
    required this.amount,
    required this.currency,
    required this.plan,
  });

  factory SubscriptionCheckout.fromJson(Map<String, dynamic> json) =>
      SubscriptionCheckout(
        rpSubId: json['rp_sub_id'] as String,
        keyId: json['key_id'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'INR',
        plan: SiteOsPlan.fromKey(json['plan'] as String?),
      );
}

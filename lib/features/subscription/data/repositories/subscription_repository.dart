import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';
import '../models/plan.dart';
import '../models/subscription.dart';

/// Thrown when a billing operation fails — carries a user-safe message.
class SubscriptionException implements Exception {
  final String message;
  const SubscriptionException(this.message);
  @override
  String toString() => message;
}

/// Talks to the Razorpay billing backend.
///
/// Subscriptions are created SERVER-SIDE via the `razorpay-create-subscription`
/// edge function (the key secret never reaches the app). Plan state only
/// changes via the verified webhook, so these reads are the trustworthy view.
class SubscriptionRepository {
  /// Starts a subscription for [plan] and returns what the Razorpay checkout
  /// needs. Throws [SubscriptionException] on any failure.
  Future<SubscriptionCheckout> createCheckout(SiteOsPlan plan) async {
    try {
      final res = await supabase.functions.invoke(
        'razorpay-create-subscription',
        body: {'plan': plan.key},
      );
      if (res.status != 200) {
        throw SubscriptionException(_errorFrom(res.data));
      }
      final data = res.data;
      if (data is! Map) {
        throw const SubscriptionException('Unexpected response from server.');
      }
      return SubscriptionCheckout.fromJson(Map<String, dynamic>.from(data));
    } on SubscriptionException {
      rethrow;
    } on FunctionException catch (e) {
      logger.w('createCheckout FunctionException: ${e.details}');
      throw SubscriptionException(_errorFrom(e.details));
    } catch (e) {
      logger.e('createCheckout failed: $e');
      throw const SubscriptionException(
          "Couldn't start checkout. Please try again.");
    }
  }

  /// The most recent subscription row for [companyId], or null if none.
  Future<Subscription?> fetchCurrent(String companyId) async {
    try {
      final row = await supabase
          .from('subscriptions')
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return Subscription.fromJson(row);
    } catch (e) {
      logger.w('fetchCurrent subscription failed: $e');
      return null;
    }
  }

  /// Paid invoices for [companyId], newest first.
  Future<List<SubscriptionInvoice>> fetchInvoices(String companyId) async {
    try {
      final rows = await supabase
          .from('subscription_invoices')
          .select()
          .eq('company_id', companyId)
          .order('paid_at', ascending: false);
      return (rows as List)
          .map((r) => SubscriptionInvoice.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.w('fetchInvoices failed: $e');
      return [];
    }
  }

  String _errorFrom(dynamic data) {
    if (data is Map && data['error'] is String) return data['error'] as String;
    return 'Something went wrong. Please try again.';
  }
}

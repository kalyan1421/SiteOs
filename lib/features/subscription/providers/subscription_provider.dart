import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/subscription.dart';
import '../data/repositories/subscription_repository.dart';

final subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>((ref) => SubscriptionRepository());

/// The current company's most recent subscription (null if never subscribed).
final currentSubscriptionProvider =
    FutureProvider<Subscription?>((ref) async {
  final companyId = ref.watch(userProfileProvider)?.companyId;
  if (companyId == null) return null;
  return ref.watch(subscriptionRepositoryProvider).fetchCurrent(companyId);
});

/// Billing history (paid invoices, newest first) for the current company.
final invoicesProvider =
    FutureProvider<List<SubscriptionInvoice>>((ref) async {
  final companyId = ref.watch(userProfileProvider)?.companyId;
  if (companyId == null) return const [];
  return ref.watch(subscriptionRepositoryProvider).fetchInvoices(companyId);
});

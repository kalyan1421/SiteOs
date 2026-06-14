import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/client.dart';
import '../data/models/gst_config.dart';
import '../data/models/project_contract.dart';
import '../data/models/ra_bill.dart';
import '../data/repositories/ra_billing_repository.dart';

/// Single repository instance for the RA-billing feature.
final raBillingRepositoryProvider =
    Provider<RaBillingRepository>((ref) => RaBillingRepository());

/// The current signed-in company id, or null when unavailable.
final billingCompanyIdProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider)?.companyId;
});

/// The company's GST config (nullable — null means "not configured yet").
final gstConfigProvider = FutureProvider<GstConfig?>((ref) async {
  final companyId = ref.watch(billingCompanyIdProvider);
  if (companyId == null) return null;
  return ref.watch(raBillingRepositoryProvider).fetchGstConfig(companyId);
});

/// All clients for the company.
final clientsProvider = FutureProvider<List<BillingClient>>((ref) async {
  final companyId = ref.watch(billingCompanyIdProvider);
  if (companyId == null) return const [];
  return ref.watch(raBillingRepositoryProvider).fetchClients(companyId);
});

/// All contracts for the company (with joined client name + state).
final contractsProvider = FutureProvider<List<ProjectContract>>((ref) async {
  final companyId = ref.watch(billingCompanyIdProvider);
  if (companyId == null) return const [];
  return ref.watch(raBillingRepositoryProvider).fetchContracts(companyId);
});

/// A single contract by id.
final contractProvider =
    FutureProvider.family<ProjectContract?, String>((ref, id) async {
  return ref.watch(raBillingRepositoryProvider).fetchContract(id);
});

/// All RA bills for the company.
final raBillsProvider = FutureProvider<List<RaBill>>((ref) async {
  final companyId = ref.watch(billingCompanyIdProvider);
  if (companyId == null) return const [];
  return ref.watch(raBillingRepositoryProvider).fetchBills(companyId);
});

/// A single RA bill by id (with joined contract + client name).
final raBillProvider =
    FutureProvider.family<RaBill?, String>((ref, id) async {
  return ref.watch(raBillingRepositoryProvider).fetchBill(id);
});

/// Baseline data needed to seed a new RA bill for a contract:
/// the previous cumulative work done and the advance already recovered.
class RaBillSeed {
  final double previousCumulative;
  final double advanceRecoveredSoFar;
  final String suggestedNumber;

  const RaBillSeed({
    required this.previousCumulative,
    required this.advanceRecoveredSoFar,
    required this.suggestedNumber,
  });
}

final raBillSeedProvider =
    FutureProvider.family<RaBillSeed, String>((ref, contractId) async {
  final repo = ref.watch(raBillingRepositoryProvider);
  final previous = await repo.latestCumulativeForContract(contractId);
  final recovered = await repo.totalAdvanceRecovered(contractId);
  final number = await repo.nextBillNumber(contractId);
  return RaBillSeed(
    previousCumulative: previous,
    advanceRecoveredSoFar: recovered,
    suggestedNumber: number,
  );
});

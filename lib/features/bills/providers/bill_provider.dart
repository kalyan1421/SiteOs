import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../data/models/bill_model.dart';
import '../data/repositories/bill_repository.dart';

// ============================================================
// CONSTANTS
// ============================================================

/// Passed to dashboardBillsCombined/Stream/Fetch providers to mean
/// "admin sees all projects". Defined once so a future role change
/// only needs updating here.
const bool kAdminSeesAllBills = false;

// ============================================================
// REPOSITORY PROVIDER
// ============================================================

final billRepositoryProvider = Provider<BillRepository>((ref) {
  return BillRepository();
});

// ============================================================
// STREAMS (READ)
// ============================================================

/// Real-time stream of bills for a specific project (autoDispose to
/// release the subscription when we navigate away).
final billsStreamProvider =
    StreamProvider.autoDispose.family<List<BillModel>, String>((
  ref,
  projectId,
) {
  final repository = ref.watch(billRepositoryProvider);
  return repository.streamBillsByProject(projectId);
});

/// Baseline fetch of bills (non-realtime).
final billsProvider =
    FutureProvider.autoDispose.family<List<BillModel>, String>((
  ref,
  projectId,
) {
  final repository = ref.watch(billRepositoryProvider);
  return repository.fetchBills(projectId);
});

/// Combined provider: initial fetch + realtime overlay
final billsCombinedProvider =
    Provider.family<AsyncValue<List<BillModel>>, String>((ref, projectId) {
      final fetchAsync = ref.watch(billsProvider(projectId));
      final streamAsync = ref.watch(billsStreamProvider(projectId));

      return fetchAsync.when(
        data: (fetched) {
          return streamAsync.when(
            data: (streamed) {
              // Merge by id (upsert) using streamed as latest
              final byId = {for (var b in fetched) b.id: b};
              for (final b in streamed) {
                final existing = byId[b.id];
                byId[b.id] = existing == null
                    ? b
                    : _mergeBillSnapshot(existing, b);
              }
              return AsyncValue.data(
                byId.values.toList()..sort(
                  (a, b) =>
                      (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                          .compareTo(
                            a.createdAt ??
                                DateTime.fromMillisecondsSinceEpoch(0),
                          ),
                ),
              );
            },
            loading: () => AsyncValue.data(fetched),
            error: (e, st) {
              logger.w(
                'Bills realtime stream unavailable, using fetched snapshot: $e',
              );
              return AsyncValue.data(fetched);
            },
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Real-time stream of bills for dashboard (all accessible or only assigned project bills)
final dashboardBillsStreamProvider =
    StreamProvider.family<List<BillModel>, bool>((
      ref,
      onlyAssignedProjects,
    ) {
      final repository = ref.watch(billRepositoryProvider);
      return repository.streamBillsForDashboard(
        onlyAssignedProjects: onlyAssignedProjects,
      );
    });

/// Baseline fetch for dashboard bills
final dashboardBillsProvider = FutureProvider.family<List<BillModel>, bool>((
  ref,
  onlyAssignedProjects,
) {
  final repository = ref.watch(billRepositoryProvider);
  return repository.fetchBillsForDashboard(
    onlyAssignedProjects: onlyAssignedProjects,
  );
});

/// Combined provider for dashboard bills
final dashboardBillsCombinedProvider =
    Provider.family<AsyncValue<List<BillModel>>, bool>((
      ref,
      onlyAssignedProjects,
    ) {
      final fetchAsync = ref.watch(
        dashboardBillsProvider(onlyAssignedProjects),
      );
      final streamAsync = ref.watch(
        dashboardBillsStreamProvider(onlyAssignedProjects),
      );

      return fetchAsync.when(
        data: (fetched) {
          return streamAsync.when(
            data: (streamed) {
              final byId = {for (var b in fetched) b.id: b};
              for (final b in streamed) {
                final existing = byId[b.id];
                byId[b.id] = existing == null
                    ? b
                    : _mergeBillSnapshot(existing, b);
              }
              final items = byId.values.toList()
                ..sort(
                  (a, b) =>
                      (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                          .compareTo(
                            a.createdAt ??
                                DateTime.fromMillisecondsSinceEpoch(0),
                          ),
                );
              return AsyncValue.data(items);
            },
            loading: () => AsyncValue.data(fetched),
            error: (e, st) {
              logger.w(
                'Dashboard bills realtime stream unavailable, using fetched snapshot: $e',
              );
              return AsyncValue.data(fetched);
            },
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Fetch pending bills with pagination
final paginatedPendingBillsProvider =
    FutureProvider.family<
      List<BillModel>,
      ({String projectId, int offset, int limit})
    >((ref, params) {
      final repository = ref.watch(billRepositoryProvider);
      return repository.getPendingBills(
        projectId: params.projectId,
        offset: params.offset,
        limit: params.limit,
      );
    });

// ============================================================
// CONTROLLER (WRITE)
// ============================================================

class BillController extends StateNotifier<AsyncValue<void>> {
  final BillRepository _repository;

  BillController(this._repository) : super(const AsyncValue.data(null));

  Future<bool> createBill({
    required String projectId,
    required String title,
    required double amount,
    required String billType,
    String? description,
    String? vendorName,
    String? paymentType,
    String? paymentStatus,
    List<int>? receiptBytes,
    String? receiptName,
    DateTime? billDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createBill(
        projectId: projectId,
        title: title,
        amount: amount,
        billType: billType,
        description: description,
        vendorName: vendorName,
        paymentType: paymentType,
        paymentStatus: paymentStatus,
        receiptBytes: receiptBytes,
        receiptName: receiptName,
        billDate: billDate,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> rejectBill(String billId, {String? reason}) async {
    state = const AsyncValue.loading();
    try {
      await _repository.rejectBill(billId, reason: reason);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteBill(String billId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteBill(billId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateBill({
    required String billId,
    required Map<String, dynamic> updates,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateBill(billId, updates);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> softDeleteBill(String billId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.softDeleteBill(billId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> restoreBill(String billId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.restoreBill(billId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateBillApproval({
    required String billId,
    required PaymentStatus paymentStatus,
    required bool markCompleted,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateBillApproval(
        billId: billId,
        paymentStatus: paymentStatus,
        markCompleted: markCompleted,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// Controller Provider — NOT autoDispose so it stays alive during async operations
final billControllerProvider =
    StateNotifierProvider<BillController, AsyncValue<void>>((ref) {
      return BillController(ref.watch(billRepositoryProvider));
    });

/// Provider for fetching soft-deleted bills (admin bin)
final deletedBillsProvider = FutureProvider<List<BillModel>>((ref) {
  final repository = ref.watch(billRepositoryProvider);
  return repository.fetchDeletedBills();
});

BillModel _mergeBillSnapshot(BillModel fetched, BillModel streamed) {
  return streamed.copyWith(
    projectName: streamed.projectName ?? fetched.projectName,
    createdByName: streamed.createdByName ?? fetched.createdByName,
    raisedByName: streamed.raisedByName ?? fetched.raisedByName,
    approvedByName: streamed.approvedByName ?? fetched.approvedByName,
  );
}

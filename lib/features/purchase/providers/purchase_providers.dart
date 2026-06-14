import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/purchase_indent.dart';
import '../data/models/purchase_order.dart';
import '../data/repositories/purchase_repository.dart';

/// Singleton repository for the purchase module.
final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepository(),
);

/// All purchase indents for the current company (newest first).
final indentsProvider = FutureProvider.autoDispose<List<PurchaseIndent>>(
  (ref) async {
    final repo = ref.watch(purchaseRepositoryProvider);
    return repo.getIndents();
  },
);

/// Indents filtered to a single project.
final indentsByProjectProvider =
    FutureProvider.autoDispose.family<List<PurchaseIndent>, String>(
  (ref, projectId) async {
    final repo = ref.watch(purchaseRepositoryProvider);
    return repo.getIndents(projectId: projectId);
  },
);

/// A single indent with its line items.
final indentDetailProvider =
    FutureProvider.autoDispose.family<PurchaseIndent, String>(
  (ref, id) async {
    final repo = ref.watch(purchaseRepositoryProvider);
    return repo.getIndent(id);
  },
);

/// All purchase orders for the current company (newest first).
final purchaseOrdersProvider = FutureProvider.autoDispose<List<PurchaseOrder>>(
  (ref) async {
    final repo = ref.watch(purchaseRepositoryProvider);
    return repo.getPurchaseOrders();
  },
);

/// A single purchase order with its line items.
final purchaseOrderDetailProvider =
    FutureProvider.autoDispose.family<PurchaseOrder, String>(
  (ref, id) async {
    final repo = ref.watch(purchaseRepositoryProvider);
    return repo.getPurchaseOrder(id);
  },
);

/// Supplier options (id + name) for the PO form picker.
final supplierOptionsProvider =
    FutureProvider.autoDispose<List<({String id, String name})>>(
  (ref) async {
    final repo = ref.watch(purchaseRepositoryProvider);
    return repo.getSupplierOptions();
  },
);

/// Approved indents (eligible to seed a PO's line items).
final approvedIndentsProvider =
    FutureProvider.autoDispose<List<PurchaseIndent>>(
  (ref) async {
    final repo = ref.watch(purchaseRepositoryProvider);
    final all = await repo.getIndents();
    return all
        .where((i) => i.status == IndentStatus.approved)
        .toList();
  },
);

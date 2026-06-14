import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/subcontractor_model.dart';
import '../data/models/work_order_model.dart';
import '../data/models/sub_ra_bill_model.dart';
import '../data/repositories/subcontractor_repository.dart';

/// Single shared repository instance.
final subcontractorRepositoryProvider =
    Provider<SubcontractorRepository>((ref) => SubcontractorRepository());

/// The current company id, resolved from the signed-in user's profile.
/// Null until the profile loads — screens guard on this before writing.
final currentCompanyIdProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider)?.companyId;
});

/// Search term driving the subcontractor list.
final subcontractorSearchProvider = StateProvider<String>((ref) => '');

/// All subcontractors for the tenant, filtered by the live search term.
final subcontractorsProvider =
    FutureProvider.autoDispose<List<SubcontractorModel>>((ref) async {
  final repo = ref.watch(subcontractorRepositoryProvider);
  final search = ref.watch(subcontractorSearchProvider);
  return repo.getSubcontractors(search: search);
});

/// A single subcontractor by id.
final subcontractorProvider = FutureProvider.autoDispose
    .family<SubcontractorModel, String>((ref, id) async {
  final repo = ref.watch(subcontractorRepositoryProvider);
  return repo.getSubcontractor(id);
});

/// Work orders for a given subcontractor (id). Pass an empty string for all.
final workOrdersProvider = FutureProvider.autoDispose
    .family<List<WorkOrderModel>, String>((ref, subcontractorId) async {
  final repo = ref.watch(subcontractorRepositoryProvider);
  return repo.getWorkOrders(
    subcontractorId: subcontractorId.isEmpty ? null : subcontractorId,
  );
});

/// A single work order by id (with subcontractor + project names joined).
final workOrderProvider =
    FutureProvider.autoDispose.family<WorkOrderModel, String>((ref, id) async {
  final repo = ref.watch(subcontractorRepositoryProvider);
  return repo.getWorkOrder(id);
});

/// RA bills raised against a work order (id).
final raBillsProvider = FutureProvider.autoDispose
    .family<List<SubRaBillModel>, String>((ref, workOrderId) async {
  final repo = ref.watch(subcontractorRepositoryProvider);
  return repo.getRaBills(workOrderId);
});

/// {id, name} project options for the work-order form's project dropdown.
final projectOptionsProvider =
    FutureProvider.autoDispose<List<({String id, String name})>>((ref) async {
  final repo = ref.watch(subcontractorRepositoryProvider);
  return repo.getProjectOptions();
});

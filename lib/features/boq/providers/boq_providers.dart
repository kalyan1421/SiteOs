import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/boq_header_model.dart';
import '../data/models/boq_item_model.dart';
import '../data/models/boq_vs_actual_row.dart';
import '../data/repositories/boq_repository.dart';

/// Singleton repository for the BOQ module.
final boqRepositoryProvider = Provider<BoqRepository>((ref) {
  return BoqRepository();
});

/// All BOQ headers for a given project (newest first, with rolled-up totals).
final boqHeadersProvider =
    FutureProvider.family<List<BoqHeaderModel>, String>((ref, projectId) async {
  final repo = ref.watch(boqRepositoryProvider);
  return repo.getHeadersForProject(projectId);
});

/// A single BOQ header by id.
final boqHeaderProvider =
    FutureProvider.family<BoqHeaderModel, String>((ref, boqId) async {
  final repo = ref.watch(boqRepositoryProvider);
  return repo.getHeader(boqId);
});

/// All line items for a BOQ (ordered by category, then sort order).
final boqItemsProvider =
    FutureProvider.family<List<BoqItemModel>, String>((ref, boqId) async {
  final repo = ref.watch(boqRepositoryProvider);
  return repo.getItems(boqId);
});

/// Arguments for the BOQ-vs-actual comparison.
class BoqVsActualArgs {
  final String boqId;
  final String projectId;

  const BoqVsActualArgs({required this.boqId, required this.projectId});

  @override
  bool operator ==(Object other) =>
      other is BoqVsActualArgs &&
      other.boqId == boqId &&
      other.projectId == projectId;

  @override
  int get hashCode => Object.hash(boqId, projectId);
}

/// Per-category estimate-vs-actual comparison for a BOQ.
final boqVsActualProvider =
    FutureProvider.family<List<BoqVsActualRow>, BoqVsActualArgs>(
        (ref, args) async {
  final repo = ref.watch(boqRepositoryProvider);
  return repo.getBoqVsActual(boqId: args.boqId, projectId: args.projectId);
});

/// Convenience: the current user's company id (required to write BOQ rows).
/// Returns null when the profile/company isn't resolved yet.
final boqCompanyIdProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider)?.companyId;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/rera_report.dart';
import '../data/repositories/rera_repository.dart';

/// Singleton repository for the RERA feature.
final reraRepositoryProvider = Provider<ReraRepository>((ref) {
  return ReraRepository();
});

/// All RERA quarterly reports for the current company (newest period first).
///
/// Refreshable via `ref.invalidate(reraReportsProvider)` after a write.
final reraReportsProvider = FutureProvider<List<ReraReport>>((ref) async {
  final repo = ref.watch(reraRepositoryProvider);
  return repo.getReports();
});

/// RERA reports filtered to a single project.
final reraReportsByProjectProvider =
    FutureProvider.family<List<ReraReport>, String>((ref, projectId) async {
  final repo = ref.watch(reraRepositoryProvider);
  return repo.getReportsForProject(projectId);
});

/// A single RERA report by id (used by the form in edit mode).
final reraReportProvider =
    FutureProvider.family<ReraReport?, String>((ref, id) async {
  final repo = ref.watch(reraRepositoryProvider);
  return repo.getReport(id);
});

/// Project options for the report form's dropdown.
final reraProjectOptionsProvider =
    FutureProvider<List<ReraProjectRef>>((ref) async {
  final repo = ref.watch(reraRepositoryProvider);
  return repo.getProjectOptions();
});

/// Geotagged photos for a project's RERA timeline (placeholder source for now).
final reraTimelinePhotosProvider =
    FutureProvider.family<List<ReraTimelinePhoto>, String>(
        (ref, projectId) async {
  final repo = ref.watch(reraRepositoryProvider);
  return repo.getTimelinePhotos(projectId);
});

/// Aggregate dashboard stats derived from the report list.
class ReraDashboardStats {
  final int totalReports;
  final int draftCount;
  final int submittedCount;
  final int approvedCount;
  final double totalFundsReceived;
  final double totalFundsUtilized;

  const ReraDashboardStats({
    required this.totalReports,
    required this.draftCount,
    required this.submittedCount,
    required this.approvedCount,
    required this.totalFundsReceived,
    required this.totalFundsUtilized,
  });

  double get totalFundsBalance => totalFundsReceived - totalFundsUtilized;

  factory ReraDashboardStats.fromReports(List<ReraReport> reports) {
    var draft = 0, submitted = 0, approved = 0;
    var received = 0.0, utilized = 0.0;
    for (final r in reports) {
      switch (r.status) {
        case ReraReportStatus.draft:
          draft++;
        case ReraReportStatus.submitted:
          submitted++;
        case ReraReportStatus.approved:
          approved++;
      }
      received += r.fundsReceived;
      utilized += r.fundsUtilized;
    }
    return ReraDashboardStats(
      totalReports: reports.length,
      draftCount: draft,
      submittedCount: submitted,
      approvedCount: approved,
      totalFundsReceived: received,
      totalFundsUtilized: utilized,
    );
  }
}

/// Dashboard stats provider derived from [reraReportsProvider].
final reraDashboardStatsProvider = Provider<AsyncValue<ReraDashboardStats>>((ref) {
  final reports = ref.watch(reraReportsProvider);
  return reports.whenData(ReraDashboardStats.fromReports);
});

/// The current user's company id, or null if unavailable. Required to create
/// reports (satisfies the RLS WITH CHECK on `rera_reports`).
final reraCompanyIdProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider)?.companyId;
});

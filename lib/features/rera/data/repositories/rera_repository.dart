import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';
import '../models/rera_report.dart';

/// All Supabase access for the RERA Quarterly Reporting feature.
///
/// Screens never touch Supabase directly — they go through this repository.
/// RLS on `rera_reports` (migration 061) scopes every read/write to the
/// caller's company, so company filtering happens server-side; we still set
/// company_id on inserts to satisfy the NOT NULL + WITH CHECK policy.
class ReraRepository {
  final SupabaseClient _client;

  ReraRepository({SupabaseClient? client}) : _client = client ?? supabase;

  static const String _table = 'rera_reports';

  /// All RERA reports for the current company, newest period first.
  /// Joins the project name for display.
  Future<List<ReraReport>> getReports() async {
    final rows = await _client
        .from(_table)
        .select('*, projects(name)')
        .order('year', ascending: false)
        .order('quarter', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => ReraReport.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Reports for a single project, newest period first.
  Future<List<ReraReport>> getReportsForProject(String projectId) async {
    final rows = await _client
        .from(_table)
        .select('*, projects(name)')
        .eq('project_id', projectId)
        .order('year', ascending: false)
        .order('quarter', ascending: false);

    return (rows as List)
        .map((r) => ReraReport.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// A single report by id, or null if not found / not accessible.
  Future<ReraReport?> getReport(String id) async {
    final row = await _client
        .from(_table)
        .select('*, projects(name)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ReraReport.fromJson(row);
  }

  /// Insert a new quarterly report. [companyId] must be the caller's company
  /// (from the user profile) to pass the RLS WITH CHECK policy.
  Future<ReraReport> createReport({
    required String companyId,
    required String projectId,
    required int quarter,
    required int year,
    required double completionPct,
    String? workDescription,
    required double fundsReceived,
    required double fundsUtilized,
    ReraReportStatus status = ReraReportStatus.draft,
  }) async {
    final payload = {
      'company_id': companyId,
      'project_id': projectId,
      'quarter': quarter,
      'year': year,
      'completion_pct': completionPct,
      'work_description': workDescription,
      'funds_received': fundsReceived,
      'funds_utilized': fundsUtilized,
      'status': status.value,
      'created_by': _client.auth.currentUser?.id,
    };

    final row = await _client
        .from(_table)
        .insert(payload)
        .select('*, projects(name)')
        .single();
    return ReraReport.fromJson(row);
  }

  /// Update an existing report.
  Future<ReraReport> updateReport({
    required String id,
    required int quarter,
    required int year,
    required double completionPct,
    String? workDescription,
    required double fundsReceived,
    required double fundsUtilized,
    required ReraReportStatus status,
  }) async {
    final payload = {
      'quarter': quarter,
      'year': year,
      'completion_pct': completionPct,
      'work_description': workDescription,
      'funds_received': fundsReceived,
      'funds_utilized': fundsUtilized,
      'status': status.value,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final row = await _client
        .from(_table)
        .update(payload)
        .eq('id', id)
        .select('*, projects(name)')
        .single();
    return ReraReport.fromJson(row);
  }

  /// Change only the filing status (e.g. draft → submitted).
  Future<ReraReport> setStatus(String id, ReraReportStatus status) async {
    final row = await _client
        .from(_table)
        .update({
          'status': status.value,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select('*, projects(name)')
        .single();
    return ReraReport.fromJson(row);
  }

  /// Delete a report.
  Future<void> deleteReport(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  /// Active projects for the current company, for the report form's dropdown.
  /// Scoped by RLS on the `projects` table.
  Future<List<ReraProjectRef>> getProjectOptions() async {
    final rows = await _client
        .from('projects')
        .select('id, name')
        .order('name', ascending: true);

    return (rows as List)
        .map((r) => ReraProjectRef.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Geotagged site photos for a project's RERA timeline.
  ///
  /// A dedicated project-photos table does not exist yet (Phase 3+). Until it
  /// lands this returns an empty list and the timeline screen renders a
  /// placeholder empty state. Wiring this to a real source later only requires
  /// changing this method — the screen contract ([ReraTimelinePhoto]) is stable.
  Future<List<ReraTimelinePhoto>> getTimelinePhotos(String projectId) async {
    return const <ReraTimelinePhoto>[];
  }
}

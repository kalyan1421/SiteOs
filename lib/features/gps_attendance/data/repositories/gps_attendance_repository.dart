import '../../../../core/config/supabase_client.dart';
import '../models/gps_checkin.dart';
import '../models/project_geofence.dart';
import '../models/project_option.dart';

/// All Supabase access for the GPS / geofencing attendance feature.
///
/// Tables: `project_geofences`, `gps_checkins` (migration 059). Every write
/// stamps `company_id` so RLS (company_id = current_company_id()) accepts it.
class GpsAttendanceRepository {
  GpsAttendanceRepository();

  // ── Projects / labour pickers ─────────────────────────────────────

  /// Active projects for the current company, for the picker dropdowns.
  Future<List<ProjectOption>> getProjects() async {
    final rows = await supabase
        .from('projects')
        .select('id, name')
        .order('name', ascending: true);
    return (rows as List)
        .map((e) => ProjectOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Active labour assigned to a project, for the check-in picker.
  Future<List<LabourOption>> getLabourForProject(String projectId) async {
    final rows = await supabase
        .from('labour')
        .select('id, name')
        .eq('project_id', projectId)
        .eq('status', 'active')
        .order('name', ascending: true);
    return (rows as List)
        .map((e) => LabourOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Geofences ─────────────────────────────────────────────────────

  /// The geofence configured for [projectId], or null if none is set yet.
  Future<ProjectGeofence?> getGeofenceForProject(String projectId) async {
    final row = await supabase
        .from('project_geofences')
        .select('*, projects(name)')
        .eq('project_id', projectId)
        .maybeSingle();
    if (row == null) return null;
    return ProjectGeofence.fromJson(row);
  }

  /// All geofences for the current company (admin overview).
  Future<List<ProjectGeofence>> getGeofences() async {
    final rows = await supabase
        .from('project_geofences')
        .select('*, projects(name)')
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((e) => ProjectGeofence.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create or update the geofence for a project (one geofence per project,
  /// enforced by the unique index). Returns the saved row.
  Future<ProjectGeofence> upsertGeofence({
    required String companyId,
    required String projectId,
    required double lat,
    required double lng,
    required int radiusM,
    String? label,
    String? createdBy,
  }) async {
    final payload = {
      'company_id': companyId,
      'project_id': projectId,
      'lat': lat,
      'lng': lng,
      'radius_m': radiusM,
      if (label != null && label.isNotEmpty) 'label': label,
      if (createdBy != null) 'created_by': createdBy,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final row = await supabase
        .from('project_geofences')
        .upsert(payload, onConflict: 'project_id')
        .select('*, projects(name)')
        .single();
    return ProjectGeofence.fromJson(row);
  }

  // ── Check-ins ─────────────────────────────────────────────────────

  /// Record a check-in. Caller computes [distanceM] / [withinGeofence] from
  /// the device location and the project geofence.
  Future<GpsCheckin> recordCheckin({
    required String companyId,
    required String projectId,
    String? labourId,
    String? userId,
    required double lat,
    required double lng,
    required double distanceM,
    required bool withinGeofence,
  }) async {
    final payload = {
      'company_id': companyId,
      'project_id': projectId,
      if (labourId != null) 'labour_id': labourId,
      if (userId != null) 'user_id': userId,
      'lat': lat,
      'lng': lng,
      'distance_m': distanceM,
      'within_geofence': withinGeofence,
      'checked_in_at': DateTime.now().toUtc().toIso8601String(),
    };

    final row = await supabase
        .from('gps_checkins')
        .insert(payload)
        .select('*, projects(name), labour(name)')
        .single();
    return GpsCheckin.fromJson(row);
  }

  /// Recent check-ins, optionally filtered to a single project.
  Future<List<GpsCheckin>> getRecentCheckins({
    String? projectId,
    int limit = 50,
  }) async {
    var query = supabase
        .from('gps_checkins')
        .select('*, projects(name), labour(name)');
    if (projectId != null) {
      query = query.eq('project_id', projectId);
    }
    final rows = await query
        .order('checked_in_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => GpsCheckin.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

import '../../../../core/config/supabase_client.dart';
import '../models/client_bill.dart';
import '../models/client_photo.dart';
import '../models/client_project.dart';

/// Read-only Supabase access for the Client Portal.
///
/// Every method is SELECT-only. Row visibility is enforced server-side by the
/// RLS policies added in migration 058 (the client may only read projects they
/// have a `client_project_access` row for, plus the photos and bills tied to
/// those projects). This repository never mutates data.
class ClientPortalRepository {
  /// Projects the signed-in client has been granted access to.
  ///
  /// Reads through `client_project_access` (which the client can read its own
  /// rows of) and joins the allowed `projects` columns.
  Future<List<ClientProject>> fetchProjects() async {
    try {
      final rows = await supabase
          .from('client_project_access')
          .select(
            'project_id, '
            'projects:project_id ('
            'id, name, description, location, client_name, project_type, '
            'status, progress, start_date, end_date, budget, deleted_at'
            ')',
          )
          .order('created_at', ascending: false);

      final list = (rows as List)
          .map((r) => (r as Map<String, dynamic>)['projects'])
          .whereType<Map<String, dynamic>>()
          .where((p) => p['deleted_at'] == null)
          .map(ClientProject.fromJson)
          .toList();
      return list;
    } catch (e) {
      logger.w('ClientPortalRepository.fetchProjects failed: $e');
      rethrow;
    }
  }

  /// A single assigned project (RLS guarantees the client may read it).
  Future<ClientProject?> fetchProject(String projectId) async {
    try {
      final row = await supabase
          .from('projects')
          .select(
            'id, name, description, location, client_name, project_type, '
            'status, progress, start_date, end_date, budget',
          )
          .eq('id', projectId)
          .maybeSingle();
      if (row == null) return null;
      return ClientProject.fromJson(row);
    } catch (e) {
      logger.w('ClientPortalRepository.fetchProject failed: $e');
      rethrow;
    }
  }

  /// Read-only progress-photo timeline for an assigned project.
  ///
  /// Tries `project_photos` first; if that table is absent on this deployment
  /// (PostgREST 404 / undefined table), falls back to image/PDF rows in
  /// `blueprints`. Either way it is SELECT-only and RLS-scoped.
  Future<List<ClientPhoto>> fetchPhotos(String projectId) async {
    try {
      final rows = await supabase
          .from('project_photos')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => ClientPhoto.fromPhotoJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.i('project_photos unavailable, falling back to blueprints: $e');
      return _fetchPhotosFromBlueprints(projectId);
    }
  }

  Future<List<ClientPhoto>> _fetchPhotosFromBlueprints(String projectId) async {
    try {
      final rows = await supabase
          .from('blueprints')
          .select('id, project_id, title, description, file_url, file_type, created_at')
          .eq('project_id', projectId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => ClientPhoto.fromBlueprintJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.w('ClientPortalRepository._fetchPhotosFromBlueprints failed: $e');
      return const [];
    }
  }

  /// Read-only RA / progress bill status list for an assigned project.
  Future<List<ClientBill>> fetchBills(String projectId) async {
    try {
      final rows = await supabase
          .from('bills')
          .select(
            'id, project_id, title, description, amount, bill_type, status, '
            'bill_date, due_date',
          )
          .eq('project_id', projectId)
          .order('bill_date', ascending: false);
      return (rows as List)
          .map((r) => ClientBill.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.w('ClientPortalRepository.fetchBills failed: $e');
      rethrow;
    }
  }
}

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';
import '../models/snag.dart';

/// All Supabase access for snags and their before/after photos. Photos live in
/// the 'snags' Storage bucket under '<project_id>/<snag_id>/<file>'.
class SnagRepository {
  static const String bucket = 'snags';

  final SupabaseClient _client;

  SnagRepository({SupabaseClient? client}) : _client = client ?? supabase;

  /// Lists snags for a project, each hydrated with its photos.
  Future<List<Snag>> getSnags(String projectId) async {
    final rows = await _client
        .from('snags')
        .select('*, snag_photos(*)')
        .eq('project_id', projectId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Snag.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Snag> getSnag(String snagId) async {
    final row = await _client
        .from('snags')
        .select('*, snag_photos(*)')
        .eq('id', snagId)
        .single();
    return Snag.fromJson(row);
  }

  Future<Snag> createSnag({
    required String companyId,
    required String projectId,
    required String title,
    String? description,
    String? location,
    String? checklistItemId,
    SnagPriority priority = SnagPriority.medium,
    String? raisedBy,
    String? assignedTo,
  }) async {
    final row = await _client
        .from('snags')
        .insert({
          'company_id': companyId,
          'project_id': projectId,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (location != null && location.isNotEmpty) 'location': location,
          if (checklistItemId != null) 'checklist_item_id': checklistItemId,
          'priority': priority.value,
          'status': SnagStatus.open.value,
          if (raisedBy != null) 'raised_by': raisedBy,
          if (assignedTo != null) 'assigned_to': assignedTo,
        })
        .select('*, snag_photos(*)')
        .single();
    return Snag.fromJson(row);
  }

  Future<Snag> updateSnag({
    required String snagId,
    String? title,
    String? description,
    String? location,
    SnagPriority? priority,
    SnagStatus? status,
    String? assignedTo,
  }) async {
    final updates = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (priority != null) 'priority': priority.value,
      if (status != null) 'status': status.value,
      if (assignedTo != null) 'assigned_to': assignedTo,
    };
    final row = await _client
        .from('snags')
        .update(updates)
        .eq('id', snagId)
        .select('*, snag_photos(*)')
        .single();
    return Snag.fromJson(row);
  }

  /// Marks a snag resolved with optional notes and resolver.
  Future<Snag> resolveSnag({
    required String snagId,
    String? resolutionNotes,
    String? resolvedBy,
  }) async {
    final row = await _client
        .from('snags')
        .update({
          'status': SnagStatus.resolved.value,
          if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
          if (resolvedBy != null) 'resolved_by': resolvedBy,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', snagId)
        .select('*, snag_photos(*)')
        .single();
    return Snag.fromJson(row);
  }

  Future<void> deleteSnag(String snagId) async {
    await _client.from('snags').delete().eq('id', snagId);
  }

  // ── Photos ─────────────────────────────────────────────────────────────────

  /// Uploads photo [bytes] to the 'snags' bucket and records a snag_photos row.
  /// Returns the created [SnagPhoto].
  Future<SnagPhoto> uploadSnagPhoto({
    required String companyId,
    required String projectId,
    required String snagId,
    required Uint8List bytes,
    required String fileName,
    required SnagPhotoKind kind,
    String? uploadedBy,
    String contentType = 'image/jpeg',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$projectId/$snagId/${kind.value}_${timestamp}_$sanitized';

    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);

    final row = await _client
        .from('snag_photos')
        .insert({
          'company_id': companyId,
          'snag_id': snagId,
          'photo_url': publicUrl,
          'storage_path': path,
          'kind': kind.value,
          if (uploadedBy != null) 'uploaded_by': uploadedBy,
        })
        .select()
        .single();
    return SnagPhoto.fromJson(row);
  }

  Future<void> deleteSnagPhoto(SnagPhoto photo) async {
    if (photo.storagePath != null) {
      try {
        await _client.storage.from(bucket).remove([photo.storagePath!]);
      } catch (_) {
        // Storage object may already be gone; the row delete is the source of
        // truth so we continue.
      }
    }
    await _client.from('snag_photos').delete().eq('id', photo.id);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';
import '../models/checklist_template.dart';
import '../models/project_checklist.dart';

/// All Supabase access for QA/QC checklist templates and project checklists.
///
/// `company_id` is always passed explicitly on insert (RLS also enforces it)
/// because the caller knows the current company from the auth profile.
class ChecklistRepository {
  final SupabaseClient _client;

  ChecklistRepository({SupabaseClient? client}) : _client = client ?? supabase;

  // ── Templates ────────────────────────────────────────────────────────────

  Future<List<ChecklistTemplate>> getTemplates() async {
    final rows = await _client
        .from('checklist_templates')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => ChecklistTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChecklistTemplate> createTemplate({
    required String companyId,
    required String name,
    String? description,
    String? category,
    String? createdBy,
  }) async {
    final row = await _client
        .from('checklist_templates')
        .insert({
          'company_id': companyId,
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (category != null && category.isNotEmpty) 'category': category,
          if (createdBy != null) 'created_by': createdBy,
        })
        .select()
        .single();
    return ChecklistTemplate.fromJson(row);
  }

  Future<ChecklistTemplate> updateTemplate(ChecklistTemplate template) async {
    final row = await _client
        .from('checklist_templates')
        .update({
          'name': template.name,
          'description': template.description,
          'category': template.category,
          'is_active': template.isActive,
        })
        .eq('id', template.id)
        .select()
        .single();
    return ChecklistTemplate.fromJson(row);
  }

  Future<void> deleteTemplate(String templateId) async {
    await _client.from('checklist_templates').delete().eq('id', templateId);
  }

  // ── Template items ─────────────────────────────────────────────────────────

  Future<List<ChecklistTemplateItem>> getTemplateItems(
      String templateId) async {
    final rows = await _client
        .from('checklist_template_items')
        .select()
        .eq('template_id', templateId)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((e) => ChecklistTemplateItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChecklistTemplateItem> addTemplateItem({
    required String companyId,
    required String templateId,
    required String title,
    String? description,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('checklist_template_items')
        .insert({
          'company_id': companyId,
          'template_id': templateId,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return ChecklistTemplateItem.fromJson(row);
  }

  Future<void> deleteTemplateItem(String itemId) async {
    await _client.from('checklist_template_items').delete().eq('id', itemId);
  }

  // ── Project checklists ─────────────────────────────────────────────────────

  /// Returns checklists for a project with item-count aggregates filled in.
  Future<List<ProjectChecklist>> getProjectChecklists(String projectId) async {
    final rows = await _client
        .from('project_checklists')
        .select('*, checklist_items(id, status)')
        .eq('project_id', projectId)
        .order('created_at', ascending: false);

    return (rows as List).map((e) {
      final map = e as Map<String, dynamic>;
      final items = (map['checklist_items'] as List?) ?? const [];
      final total = items.length;
      final completed = items.where((i) {
        final s = (i as Map)['status'] as String?;
        return s != null && s != 'pending';
      }).length;
      return ProjectChecklist.fromJson(map).copyWith(
        totalItems: total,
        completedItems: completed,
      );
    }).toList();
  }

  /// Creates a project checklist. If [templateId] is provided, copies the
  /// template's items into `checklist_items`.
  Future<ProjectChecklist> createProjectChecklist({
    required String companyId,
    required String projectId,
    required String name,
    String? templateId,
    String? createdBy,
  }) async {
    final row = await _client
        .from('project_checklists')
        .insert({
          'company_id': companyId,
          'project_id': projectId,
          'name': name,
          if (templateId != null) 'template_id': templateId,
          if (createdBy != null) 'created_by': createdBy,
        })
        .select()
        .single();
    final checklist = ProjectChecklist.fromJson(row);

    if (templateId != null) {
      final templateItems = await getTemplateItems(templateId);
      if (templateItems.isNotEmpty) {
        final payload = templateItems
            .map((t) => {
                  'company_id': companyId,
                  'project_checklist_id': checklist.id,
                  'title': t.title,
                  if (t.description != null) 'description': t.description,
                  'status': 'pending',
                  'sort_order': t.sortOrder,
                })
            .toList();
        await _client.from('checklist_items').insert(payload);
      }
    }

    return checklist;
  }

  Future<void> updateProjectChecklistStatus(
    String checklistId,
    ProjectChecklistStatus status,
  ) async {
    await _client
        .from('project_checklists')
        .update({'status': status.value})
        .eq('id', checklistId);
  }

  Future<void> deleteProjectChecklist(String checklistId) async {
    await _client.from('project_checklists').delete().eq('id', checklistId);
  }

  // ── Checklist items (pass/fail/na) ─────────────────────────────────────────

  Future<List<ChecklistItem>> getChecklistItems(String checklistId) async {
    final rows = await _client
        .from('checklist_items')
        .select()
        .eq('project_checklist_id', checklistId)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChecklistItem> addChecklistItem({
    required String companyId,
    required String checklistId,
    required String title,
    String? description,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('checklist_items')
        .insert({
          'company_id': companyId,
          'project_checklist_id': checklistId,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          'status': 'pending',
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return ChecklistItem.fromJson(row);
  }

  Future<ChecklistItem> setItemStatus({
    required String itemId,
    required ChecklistItemStatus status,
    String? notes,
    String? checkedBy,
  }) async {
    final row = await _client
        .from('checklist_items')
        .update({
          'status': status.value,
          if (notes != null) 'notes': notes,
          if (checkedBy != null) 'checked_by': checkedBy,
          'checked_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itemId)
        .select()
        .single();
    return ChecklistItem.fromJson(row);
  }

  Future<void> deleteChecklistItem(String itemId) async {
    await _client.from('checklist_items').delete().eq('id', itemId);
  }
}

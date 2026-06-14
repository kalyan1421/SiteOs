import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/checklist_template.dart';
import '../data/models/project_checklist.dart';
import '../data/models/snag.dart';
import '../data/repositories/checklist_repository.dart';
import '../data/repositories/snag_repository.dart';

/// Repository singletons.
final checklistRepositoryProvider = Provider<ChecklistRepository>(
  (ref) => ChecklistRepository(),
);

final snagRepositoryProvider = Provider<SnagRepository>(
  (ref) => SnagRepository(),
);

// ── Templates ────────────────────────────────────────────────────────────────

/// All checklist templates for the current company.
final checklistTemplatesProvider =
    FutureProvider<List<ChecklistTemplate>>((ref) async {
  return ref.watch(checklistRepositoryProvider).getTemplates();
});

/// Line items for a single template.
final templateItemsProvider =
    FutureProvider.family<List<ChecklistTemplateItem>, String>(
        (ref, templateId) async {
  return ref.watch(checklistRepositoryProvider).getTemplateItems(templateId);
});

// ── Project checklists ───────────────────────────────────────────────────────

/// Checklists scoped to a project (with progress aggregates).
final projectChecklistsProvider =
    FutureProvider.family<List<ProjectChecklist>, String>(
        (ref, projectId) async {
  return ref.watch(checklistRepositoryProvider).getProjectChecklists(projectId);
});

/// Pass/fail/na items for a single project checklist.
final checklistItemsProvider =
    FutureProvider.family<List<ChecklistItem>, String>((ref, checklistId) async {
  return ref.watch(checklistRepositoryProvider).getChecklistItems(checklistId);
});

// ── Snags ────────────────────────────────────────────────────────────────────

/// Snags scoped to a project (each hydrated with photos).
final projectSnagsProvider =
    FutureProvider.family<List<Snag>, String>((ref, projectId) async {
  return ref.watch(snagRepositoryProvider).getSnags(projectId);
});

/// A single snag with its photos.
final snagDetailProvider =
    FutureProvider.family<Snag, String>((ref, snagId) async {
  return ref.watch(snagRepositoryProvider).getSnag(snagId);
});

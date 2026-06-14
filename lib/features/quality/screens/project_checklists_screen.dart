import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/checklist_template.dart';
import '../data/models/project_checklist.dart';
import '../providers/quality_providers.dart';
import 'checklist_detail_screen.dart';

/// Lists QA/QC checklists for a project and lets the user create new ones
/// (blank or from a template).
class ProjectChecklistsScreen extends ConsumerWidget {
  final String projectId;

  const ProjectChecklistsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklists = ref.watch(projectChecklistsProvider(projectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Quality Checklists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.playlist_add),
        label: const Text('New Checklist'),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(projectChecklistsProvider(projectId)),
        child: checklists.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(projectChecklistsProvider(projectId)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const _EmptyState(
                icon: Icons.checklist_rtl,
                title: 'No checklists yet',
                subtitle:
                    'Create a checklist to start QA/QC inspections on this project.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.s3),
              itemBuilder: (_, i) => _ChecklistCard(
                checklist: items[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChecklistDetailScreen(
                      projectId: projectId,
                      checklistId: items[i].id,
                      checklistName: items[i].name,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final templatesAsync = ref.read(checklistTemplatesProvider.future);
    ChecklistTemplate? selectedTemplate;
    List<ChecklistTemplate> templates = [];
    try {
      templates = await templatesAsync;
    } catch (_) {
      templates = [];
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.s4,
                right: AppSpacing.s4,
                top: AppSpacing.s4,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                    AppSpacing.s4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Checklist', style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppSpacing.s4),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Checklist name',
                      hintText: 'e.g. Block A — Plumbing Inspection',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  if (templates.isNotEmpty) ...[
                    DropdownButtonFormField<ChecklistTemplate?>(
                      initialValue: selectedTemplate,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Start from template (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<ChecklistTemplate?>(
                          value: null,
                          child: Text('Blank checklist'),
                        ),
                        ...templates.map(
                          (t) => DropdownMenuItem<ChecklistTemplate?>(
                            value: t,
                            child: Text(t.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setSheetState(() => selectedTemplate = v),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        final profile = ref.read(userProfileProvider);
                        final companyId = profile?.companyId;
                        if (companyId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No company found for user.')),
                          );
                          return;
                        }
                        try {
                          await ref
                              .read(checklistRepositoryProvider)
                              .createProjectChecklist(
                                companyId: companyId,
                                projectId: projectId,
                                name: name,
                                templateId: selectedTemplate?.id,
                                createdBy: profile?.id,
                              );
                          ref.invalidate(
                              projectChecklistsProvider(projectId));
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        } catch (e) {
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text('Could not create: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final ProjectChecklist checklist;
  final VoidCallback onTap;

  const _ChecklistCard({required this.checklist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      checklist.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(
                    label: checklist.status.label,
                    color: checklist.status.color,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: LinearProgressIndicator(
                        value: checklist.progress,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Text(
                    '${checklist.completedItems}/${checklist.totalItems}',
                    style: AppTextStyles.mono.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 56, color: AppColors.textHint),
        const SizedBox(height: AppSpacing.s4),
        Center(
          child: Text(title, style: AppTextStyles.titleMedium),
        ),
        const SizedBox(height: AppSpacing.s2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: AppSpacing.s4),
        Center(
          child: Text('Something went wrong',
              style: AppTextStyles.titleMedium),
        ),
        const SizedBox(height: AppSpacing.s2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Center(
          child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

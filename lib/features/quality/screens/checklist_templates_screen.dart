import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/checklist_template.dart';
import '../providers/quality_providers.dart';

/// Admin screen to manage reusable QA/QC checklist templates for the company.
/// Lists templates, lets the admin create one and drill into it to manage its
/// line items.
class ChecklistTemplatesScreen extends ConsumerWidget {
  const ChecklistTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final templates = ref.watch(checklistTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checklistTemplates)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.newTemplate),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(checklistTemplatesProvider),
        child: templates.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _CenterMessage(
            icon: Icons.error_outline,
            color: AppColors.error,
            title: 'Failed to load templates',
            message: e.toString(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _CenterMessage(
                icon: Icons.fact_check_outlined,
                color: AppColors.textHint,
                title: 'No templates',
                message:
                    'Create reusable checklist templates your team can apply to projects.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
              itemBuilder: (_, i) => _TemplateCard(
                template: list[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _TemplateItemsScreen(template: list[i]),
                  ),
                ),
                onDelete: () => _deleteTemplate(context, ref, list[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    ChecklistTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: const Text('Delete template?'),
          content: Text('Delete "${template.name}" and its items?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await ref.read(checklistRepositoryProvider).deleteTemplate(template.id);
      ref.invalidate(checklistTemplatesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final categoryController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s4,
            right: AppSpacing.s4,
            top: AppSpacing.s4,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.newTemplate, style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.s4),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Template name',
                  hintText: 'e.g. Plumbing Inspection',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  hintText: 'e.g. MEP, Structural, Finishing',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.s4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final profile = ref.read(userProfileProvider);
                    final companyId = profile?.companyId;
                    if (companyId == null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                            content: Text('No company found for user.')),
                      );
                      return;
                    }
                    try {
                      await ref
                          .read(checklistRepositoryProvider)
                          .createTemplate(
                            companyId: companyId,
                            name: name,
                            description: descController.text.trim(),
                            category: categoryController.text.trim(),
                            createdBy: profile?.id,
                          );
                      ref.invalidate(checklistTemplatesProvider);
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
                  child: Text(l10n.create),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final ChecklistTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.checklist_rtl,
                    color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: AppTextStyles.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (template.category != null &&
                        template.category!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        template.category!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.textHint),
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Manages the ordered line items of a single template.
class _TemplateItemsScreen extends ConsumerWidget {
  final ChecklistTemplate template;

  const _TemplateItemsScreen({required this.template});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(templateItemsProvider(template.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(template.name, overflow: TextOverflow.ellipsis),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.addItem),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(templateItemsProvider(template.id)),
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _CenterMessage(
            icon: Icons.error_outline,
            color: AppColors.error,
            title: 'Failed to load items',
            message: e.toString(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _CenterMessage(
                icon: Icons.rule,
                color: AppColors.textHint,
                title: 'No items',
                message:
                    'Add the inspection items that make up this template.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s2),
              itemBuilder: (_, i) {
                final item = list[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surfaceVariant,
                      child: Text(
                        '${i + 1}',
                        style: AppTextStyles.labelMedium,
                      ),
                    ),
                    title: Text(item.title, style: AppTextStyles.titleSmall),
                    subtitle: (item.description != null &&
                            item.description!.isNotEmpty)
                        ? Text(item.description!,
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary))
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.textHint),
                      onPressed: () => _deleteItem(context, ref, item.id),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    String itemId,
  ) async {
    try {
      await ref.read(checklistRepositoryProvider).deleteTemplateItem(itemId);
      ref.invalidate(templateItemsProvider(template.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  Future<void> _showAddItemSheet(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final existing = ref.read(templateItemsProvider(template.id)).asData?.value;
    final nextOrder = (existing?.length ?? 0);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s4,
            right: AppSpacing.s4,
            top: AppSpacing.s4,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.addItem, style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.s4),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Item title'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.s4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    final profile = ref.read(userProfileProvider);
                    final companyId = profile?.companyId ?? template.companyId;
                    try {
                      await ref
                          .read(checklistRepositoryProvider)
                          .addTemplateItem(
                            companyId: companyId,
                            templateId: template.id,
                            title: title,
                            description: descController.text.trim(),
                            sortOrder: nextOrder,
                          );
                      ref.invalidate(templateItemsProvider(template.id));
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    } catch (e) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text('Could not add: $e')),
                        );
                      }
                    }
                  },
                  child: Text(l10n.add),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _CenterMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 52, color: color),
        const SizedBox(height: AppSpacing.s4),
        Center(child: Text(title, style: AppTextStyles.titleMedium)),
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
      ],
    );
  }
}

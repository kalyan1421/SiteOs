import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/project_checklist.dart';
import '../providers/quality_providers.dart';

/// Shows the pass/fail/na items of a single project checklist and lets the
/// inspector mark each item and add new items.
class ChecklistDetailScreen extends ConsumerWidget {
  final String projectId;
  final String checklistId;
  final String checklistName;

  const ChecklistDetailScreen({
    super.key,
    required this.projectId,
    required this.checklistId,
    required this.checklistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(checklistItemsProvider(checklistId));

    return Scaffold(
      appBar: AppBar(
        title: Text(checklistName, overflow: TextOverflow.ellipsis),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(checklistItemsProvider(checklistId)),
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
                message: 'Add inspection items to this checklist.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
              itemBuilder: (_, i) => _ChecklistItemCard(
                item: list[i],
                onStatusSelected: (status) =>
                    _setStatus(context, ref, list[i], status),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    ChecklistItem item,
    ChecklistItemStatus status,
  ) async {
    final profile = ref.read(userProfileProvider);
    try {
      await ref.read(checklistRepositoryProvider).setItemStatus(
            itemId: item.id,
            status: status,
            checkedBy: profile?.id,
          );
      ref.invalidate(checklistItemsProvider(checklistId));
      ref.invalidate(projectChecklistsProvider(projectId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update item: $e')),
        );
      }
    }
  }

  Future<void> _showAddItemSheet(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
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
              Text('Add Item', style: AppTextStyles.titleLarge),
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
                    final companyId = profile?.companyId;
                    if (companyId == null) return;
                    try {
                      await ref
                          .read(checklistRepositoryProvider)
                          .addChecklistItem(
                            companyId: companyId,
                            checklistId: checklistId,
                            title: title,
                            description: descController.text.trim(),
                          );
                      ref.invalidate(checklistItemsProvider(checklistId));
                      ref.invalidate(projectChecklistsProvider(projectId));
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
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChecklistItemCard extends StatelessWidget {
  final ChecklistItem item;
  final ValueChanged<ChecklistItemStatus> onStatusSelected;

  const _ChecklistItemCard({
    required this.item,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: AppTextStyles.titleSmall),
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s1),
              Text(
                item.description!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                _StatusButton(
                  status: ChecklistItemStatus.pass,
                  selected: item.status == ChecklistItemStatus.pass,
                  onTap: () => onStatusSelected(ChecklistItemStatus.pass),
                ),
                const SizedBox(width: AppSpacing.s2),
                _StatusButton(
                  status: ChecklistItemStatus.fail,
                  selected: item.status == ChecklistItemStatus.fail,
                  onTap: () => onStatusSelected(ChecklistItemStatus.fail),
                ),
                const SizedBox(width: AppSpacing.s2),
                _StatusButton(
                  status: ChecklistItemStatus.na,
                  selected: item.status == ChecklistItemStatus.na,
                  onTap: () => onStatusSelected(ChecklistItemStatus.na),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final ChecklistItemStatus status;
  final bool selected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(status.icon,
                  size: 20,
                  color: selected ? color : AppColors.textHint),
              const SizedBox(height: AppSpacing.s1),
              Text(
                status.label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
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

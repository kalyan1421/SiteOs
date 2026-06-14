import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/purchase_indent.dart';
import '../providers/purchase_providers.dart';
import '../widgets/purchase_widgets.dart';
import 'indent_form.dart';

/// Lists all purchase indents for the company and lets the user create new
/// ones or advance their status (submit / approve / reject).
class IndentsScreen extends ConsumerWidget {
  const IndentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIndents = ref.watch(indentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Purchase Indents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Indent'),
      ),
      body: asyncIndents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(indentsProvider),
        ),
        data: (indents) {
          if (indents.isEmpty) {
            return PurchaseEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No indents yet',
              message:
                  'Raise a material request against a project to get started.',
              actionLabel: 'New Indent',
              onAction: () => _openForm(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(indentsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: indents.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.s3),
              itemBuilder: (context, i) => _IndentCard(
                indent: indents[i],
                onStatusChange: (status) => _changeStatus(
                  context,
                  ref,
                  indents[i],
                  status,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const IndentFormScreen()),
    );
    if (created == true) ref.invalidate(indentsProvider);
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    PurchaseIndent indent,
    IndentStatus status,
  ) async {
    final repo = ref.read(purchaseRepositoryProvider);
    try {
      await repo.updateIndentStatus(indent.id!, status);
      ref.invalidate(indentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Indent marked ${status.label}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}

class _IndentCard extends StatelessWidget {
  final PurchaseIndent indent;
  final ValueChanged<IndentStatus> onStatusChange;

  const _IndentCard({required this.indent, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final itemCount = indent.items.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  indent.title?.isNotEmpty == true
                      ? indent.title!
                      : (indent.indentNo ?? 'Indent'),
                  style: AppTextStyles.titleMedium,
                ),
              ),
              StatusChip.indent(indent.status),
            ],
          ),
          if (indent.indentNo != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(indent.indentNo!, style: AppTextStyles.mono),
          ],
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 16, color: AppColors.textHint),
              const SizedBox(width: AppSpacing.s1),
              Text('$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall),
              const Spacer(),
              Icon(Icons.event_outlined, size: 16, color: AppColors.textHint),
              const SizedBox(width: AppSpacing.s1),
              Text('Need by ${PurchaseFormat.date(indent.requiredBy)}',
                  style: AppTextStyles.bodySmall),
            ],
          ),
          const Divider(height: AppSpacing.s6),
          Align(
            alignment: Alignment.centerRight,
            child: _statusActions(),
          ),
        ],
      ),
    );
  }

  Widget _statusActions() {
    switch (indent.status) {
      case IndentStatus.draft:
        return TextButton.icon(
          onPressed: () => onStatusChange(IndentStatus.submitted),
          icon: const Icon(Icons.send_outlined, size: 18),
          label: const Text('Submit'),
        );
      case IndentStatus.submitted:
        return Wrap(
          spacing: AppSpacing.s2,
          children: [
            TextButton(
              onPressed: () => onStatusChange(IndentStatus.rejected),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: () => onStatusChange(IndentStatus.approved),
              child: const Text('Approve'),
            ),
          ],
        );
      case IndentStatus.approved:
        return TextButton.icon(
          onPressed: () => onStatusChange(IndentStatus.closed),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Close'),
        );
      case IndentStatus.rejected:
      case IndentStatus.closed:
        return const SizedBox.shrink();
    }
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.s4),
            Text('Something went wrong', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.s2),
            Text(message,
                textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.s5),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

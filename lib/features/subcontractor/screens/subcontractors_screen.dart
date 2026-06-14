import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/subcontractor_model.dart';
import '../providers/subcontractor_providers.dart';
import 'subcontractor_form.dart';
import 'work_order_screen.dart';

/// Directory of all subcontractors for the tenant. Tap a card to view that
/// subcontractor's work orders; the + button creates a new one.
class SubcontractorsScreen extends ConsumerWidget {
  const SubcontractorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSubs = ref.watch(subcontractorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subcontractors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s2,
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search subcontractors',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) =>
                  ref.read(subcontractorSearchProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: asyncSubs.when(
              data: (subs) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(subcontractorsProvider),
                child: subs.isEmpty
                    ? _Empty()
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        itemCount: subs.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.s3),
                        itemBuilder: (_, i) => _SubcontractorCard(
                          subcontractor: subs[i],
                          onTap: () => _openWorkOrders(context, subs[i]),
                          onEdit: () =>
                              _openForm(context, ref, existing: subs[i]),
                        ),
                      ),
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Error(
                message: '$e',
                onRetry: () => ref.invalidate(subcontractorsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    SubcontractorModel? existing,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubcontractorForm(existing: existing),
      ),
    );
  }

  void _openWorkOrders(BuildContext context, SubcontractorModel sub) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkOrderScreen(subcontractor: sub),
      ),
    );
  }
}

class _SubcontractorCard extends StatelessWidget {
  final SubcontractorModel subcontractor;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _SubcontractorCard({
    required this.subcontractor,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final s = subcontractor;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.specialization != null &&
                        s.specialization!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        s.specialization!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (s.gstin != null && s.gstin!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s1),
                      Text('GSTIN ${s.gstin}', style: AppTextStyles.mono),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                color: AppColors.textHint,
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              const Icon(Icons.chevron_right, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.s16),
        const Icon(Icons.engineering_outlined,
            size: 56, color: AppColors.textHint),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'No subcontractors yet',
          textAlign: TextAlign.center,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Add the firms and individuals you award work to.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 40),
            const SizedBox(height: AppSpacing.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

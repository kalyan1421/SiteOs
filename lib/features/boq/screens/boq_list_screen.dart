import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/boq_header_model.dart';
import '../providers/boq_providers.dart';
import '../widgets/boq_money_text.dart';
import 'boq_form.dart';

/// Lists every BOQ (estimate) for a single project.
///
/// Route: /projects/:projectId/boq  (wrap in PlanGuard, AppFeature.boqModule).
class BoqListScreen extends ConsumerWidget {
  final String projectId;
  final String? projectName;

  const BoqListScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final headers = ref.watch(boqHeadersProvider(projectId));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.billOfQuantities, style: AppTextStyles.titleLarge),
            if (projectName != null && projectName!.isNotEmpty)
              Text(
                projectName!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.newBoq),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(boqHeadersProvider(projectId)),
        child: headers.when(
          data: (list) => list.isEmpty
              ? _Empty(onCreate: () => _openCreate(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.s3),
                  itemBuilder: (context, i) => _BoqCard(
                    header: list[i],
                    onTap: () => context.push(
                      '/projects/$projectId/boq/${list[i].id}',
                      extra: {
                        'projectName': projectName,
                        'boqName': list[i].name,
                      },
                    ),
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(boqHeadersProvider(projectId)),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.xlR),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BoqForm(projectId: projectId),
      ),
    );
    if (created == true) {
      ref.invalidate(boqHeadersProvider(projectId));
    }
  }
}

class _BoqCard extends StatelessWidget {
  final BoqHeaderModel header;
  final VoidCallback onTap;

  const _BoqCard({required this.header, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateStr = header.createdAt != null
        ? DateFormat('dd MMM yyyy').format(header.createdAt!)
        : '—';
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.calculate_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            header.name,
                            style: AppTextStyles.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        _VersionChip(version: header.version),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Created $dateStr',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l10n.total, style: AppTextStyles.overline),
                  const SizedBox(height: 2),
                  BoqMoneyText(
                    header.total ?? 0,
                    weight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.s1),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  final String version;
  const _VersionChip({required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(version,
          style: AppTextStyles.labelSmall
              .copyWith(color: AppColors.textSecondary)),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onCreate;
  const _Empty({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s8),
      children: [
        const SizedBox(height: AppSpacing.s16),
        const Icon(Icons.calculate_outlined,
            size: 56, color: AppColors.textDisabled),
        const SizedBox(height: AppSpacing.s4),
        Text(l10n.noEstimatesYet,
            style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Create your first Bill of Quantities to estimate '
          'material and work costs for this project.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s5),
        Center(
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.createBoq),
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
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s8),
      children: [
        const SizedBox(height: AppSpacing.s12),
        const Icon(Icons.error_outline_rounded,
            size: 48, color: AppColors.error),
        const SizedBox(height: AppSpacing.s4),
        Text("Couldn't load BOQs",
            style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s2),
        Text(message,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s4),
        Center(
          child: OutlinedButton(
              onPressed: onRetry, child: Text(l10n.retry)),
        ),
      ],
    );
  }
}

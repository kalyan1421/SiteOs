import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/client_project.dart';
import '../providers/client_portal_providers.dart';
import '../widgets/client_progress_bar.dart';
import '../widgets/client_state_views.dart';
import '../widgets/client_status_chip.dart';
import '../../../l10n/app_localizations.dart';

/// Read-only detail for one assigned project: completion %, key info, and
/// milestone timeline derived from the project's dates and progress.
class ClientProjectScreen extends ConsumerWidget {
  final String projectId;
  const ClientProjectScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectAsync = ref.watch(clientProjectProvider(projectId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.projectDetails)),
      body: projectAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ClientErrorState(
          onRetry: () => ref.invalidate(clientProjectProvider(projectId)),
          message: "Couldn't load this project.",
        ),
        data: (project) {
          if (project == null) {
            return const ClientEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Project not available',
              message: 'You may no longer have access to this project.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(clientProjectProvider(projectId).future),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              children: [
                _HeaderCard(project: project),
                const SizedBox(height: AppSpacing.s4),
                _QuickLinks(projectId: projectId),
                const SizedBox(height: AppSpacing.s4),
                _InfoCard(project: project),
                const SizedBox(height: AppSpacing.s4),
                _MilestonesCard(project: project),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ClientProject project;
  const _HeaderCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(project.name, style: AppTextStyles.titleLarge),
              ),
              ClientStatusChip(
                status: project.status,
                label: project.statusLabel,
              ),
            ],
          ),
          if (project.projectType != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              project.projectType!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.s5),
          ClientProgressBar(fraction: project.progressFraction),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  final String projectId;
  const _QuickLinks({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LinkTile(
            icon: Icons.photo_library_outlined,
            label: 'Photos',
            onTap: () => context.push('/client/project/$projectId/photos'),
          ),
        ),
        const SizedBox(width: AppSpacing.s4),
        Expanded(
          child: _LinkTile(
            icon: Icons.receipt_long_outlined,
            label: 'Billing',
            onTap: () => context.push('/client/project/$projectId/billing'),
          ),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s5,
            horizontal: AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: AppSpacing.s2),
              Text(label, style: AppTextStyles.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ClientProject project;
  const _InfoCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final df = DateFormat('d MMM yyyy');
    final rows = <(String, String)>[
      if (project.clientName != null) ('Client', project.clientName!),
      if (project.location != null) ('Location', project.location!),
      if (project.startDate != null) ('Start date', df.format(project.startDate!)),
      if (project.endDate != null) ('Target end', df.format(project.endDate!)),
    ];
    if (rows.isEmpty && (project.description == null)) {
      return const SizedBox.shrink();
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.overview, style: AppTextStyles.titleSmall),
          const SizedBox(height: AppSpacing.s3),
          for (final r in rows) ...[
            _InfoRow(label: r.$1, value: r.$2),
            const SizedBox(height: AppSpacing.s2),
          ],
          if (project.description != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              project.description!,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textHint),
          ),
        ),
        Expanded(
          child: Text(value, style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }
}

/// A lightweight milestone timeline derived from the project's progress and
/// status (no separate milestones table in this schema). Gives the client a
/// clear, read-only sense of the build stages.
class _MilestonesCard extends StatelessWidget {
  final ClientProject project;
  const _MilestonesCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final milestones = _deriveMilestones(project);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.milestones, style: AppTextStyles.titleSmall),
          const SizedBox(height: AppSpacing.s4),
          for (var i = 0; i < milestones.length; i++)
            _MilestoneRow(
              milestone: milestones[i],
              isLast: i == milestones.length - 1,
            ),
        ],
      ),
    );
  }

  List<_Milestone> _deriveMilestones(ClientProject p) {
    // Evenly spaced stage thresholds against the project's completion %.
    const stages = <(String, int)>[
      ('Project kickoff', 0),
      ('Foundation', 20),
      ('Structure', 45),
      ('Finishing', 75),
      ('Handover', 100),
    ];
    final progress = p.progress;
    return [
      for (final s in stages)
        _Milestone(
          title: s.$1,
          done: progress >= s.$2,
          active: progress < s.$2 &&
              (stages.indexOf(s) == 0 || progress >= stages[stages.indexOf(s) - 1].$2),
        ),
    ];
  }
}

class _Milestone {
  final String title;
  final bool done;
  final bool active;
  const _Milestone({
    required this.title,
    required this.done,
    required this.active,
  });
}

class _MilestoneRow extends StatelessWidget {
  final _Milestone milestone;
  final bool isLast;
  const _MilestoneRow({required this.milestone, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final Color dotColor = milestone.done
        ? AppColors.success
        : (milestone.active ? AppColors.accent : AppColors.borderDark);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
                child: milestone.done
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: milestone.done
                        ? AppColors.success
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.s3),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s4),
            child: Text(
              milestone.title,
              style: AppTextStyles.bodyMedium.copyWith(
                color: milestone.done || milestone.active
                    ? AppColors.textPrimary
                    : AppColors.textHint,
                fontWeight:
                    milestone.active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.sm,
      ),
      child: child,
    );
  }
}

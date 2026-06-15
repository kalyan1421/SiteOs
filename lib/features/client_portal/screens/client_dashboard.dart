import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/client_project.dart';
import '../providers/client_portal_providers.dart';
import '../widgets/client_progress_bar.dart';
import '../widgets/client_state_views.dart';
import '../widgets/client_status_chip.dart';
import '../../../l10n/app_localizations.dart';

/// Landing screen for a `role='client'` user. Read-only list of the projects
/// they have been granted access to, each linking into the project detail.
class ClientDashboard extends ConsumerWidget {
  const ClientDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(clientProjectsProvider);
    final profile = ref.watch(userProfileProvider);
    final greetingName = profile?.fullName?.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.myProjects),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(clientProjectsProvider.future),
        child: projectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            children: [
              const SizedBox(height: 120),
              ClientErrorState(
                onRetry: () => ref.invalidate(clientProjectsProvider),
                message: "Couldn't load your projects.",
              ),
            ],
          ),
          data: (projects) {
            if (projects.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  ClientEmptyState(
                    icon: Icons.folder_open_rounded,
                    title: 'No projects yet',
                    message:
                        'Your builder has not shared any projects with you. '
                        "They'll appear here once granted access.",
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              children: [
                Text('Hello, $greetingName', style: AppTextStyles.headlineSmall),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  'Track progress on your projects below.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s5),
                for (final project in projects) ...[
                  _ProjectCard(project: project),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ClientProject project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/client/project/${project.id}'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppElevation.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  ClientStatusChip(
                    status: project.status,
                    label: project.statusLabel,
                  ),
                ],
              ),
              if (project.location != null) ...[
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.textHint),
                    const SizedBox(width: AppSpacing.s1),
                    Expanded(
                      child: Text(
                        project.location!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              ClientProgressBar(fraction: project.progressFraction),
            ],
          ),
        ),
      ),
    );
  }
}

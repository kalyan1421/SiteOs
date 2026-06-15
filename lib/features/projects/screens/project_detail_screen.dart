import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/responsive_scaffold.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/project_model.dart';
import '../providers/project_provider.dart';
import 'widgets/assign_manager_sheet.dart';

/// Project detail screen with project summary and module navigation.
class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  void _navigateBack(UserRole? role) {
    switch (role) {
      case UserRole.superAdmin:
        context.go('/super-admin/dashboard');
      case UserRole.admin:
        context.go('/admin/dashboard');
      default:
        context.go('/site-manager/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectDetailProvider(widget.projectId));
    final authState = ref.watch(authProvider);
    final isAdmin = authState.isAtLeast(UserRole.admin);
    final userRole = authState.role;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _navigateBack(userRole);
      },
      child: ResponsiveScaffold(
        backgroundColor: AppColors.scaffoldBackground,
        builder: (context, r) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.maxContentWidth),
              child: Padding(
                padding: r.pad.copyWith(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Inline action bar (back + edit/delete)
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _navigateBack(userRole),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isAdmin && projectState.project != null) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppColors.textPrimary, size: 22),
                            tooltip: 'Edit project',
                            onPressed: () => context.pushNamed(
                              'edit-project',
                              pathParameters: {'id': widget.projectId},
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 22),
                            tooltip: 'Delete project',
                            onPressed: _confirmDelete,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (projectState.isLoading)
                      const LoadingWidget()
                    else if (projectState.error != null)
                      AppErrorWidget(
                        message: projectState.error!,
                        onRetry: () => ref
                            .read(projectDetailProvider(widget.projectId)
                                .notifier)
                            .refresh(),
                      )
                    else if (projectState.project == null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.folder_off_outlined,
                                  size: 28,
                                  color: AppColors.textHint,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Project not found',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'It may have been deleted or you no longer have access.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: () => _navigateBack(userRole),
                                child: Text(AppLocalizations.of(context)!.backToDashboard),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      _HeroSection(
                        project: projectState.project!,
                        isAdmin: isAdmin,
                        onEditManager: () =>
                            _showAssignManagerSheet(context),
                        onEditProject: () => context.pushNamed(
                          'edit-project',
                          pathParameters: {'id': widget.projectId},
                        ),
                        onUpdateStatus: () => _showStatusUpdateSheet(
                          context,
                          projectState.project!,
                        ),
                        onUpdateProgress: isAdmin
                            ? () => _showProgressUpdateDialog(
                                context, projectState.project!)
                            : null,
                      ),
                      const SizedBox(height: 24),
                      _ModuleNavigation(projectId: widget.projectId),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAssignManagerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssignManagerSheet(projectId: widget.projectId),
    );
  }

  void _showStatusUpdateSheet(BuildContext context, ProjectModel project) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Update Project Status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...ProjectStatus.values.map((status) {
                return ListTile(
                  leading: Icon(Icons.circle, color: status.color, size: 16),
                  title: Text(status.displayName),
                  trailing: project.status == status
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    if (project.status == status) return;

                    final notifier = ref.read(
                      projectDetailProvider(widget.projectId).notifier,
                    );
                    if (context.mounted) {
                      final success = await notifier.updateProject({
                        'status': status.value,
                      });
                      if (context.mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.statusUpdatedSuccessfully),
                            ),
                          );
                        } else {
                          final error =
                              ref
                                  .read(projectDetailProvider(widget.projectId))
                                  .error ??
                              'Failed to update status';
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                        }
                      }
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProgressUpdateDialog(
    BuildContext context,
    ProjectModel project,
  ) async {
    double sliderValue = project.progress.toDouble();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.updateCompletionPct),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${sliderValue.round()}%',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: sliderValue,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${sliderValue.round()}%',
                onChanged: (v) => setState(() => sliderValue = v),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('0%', style: TextStyle(color: AppColors.textHint)),
                  Text('100%', style: TextStyle(color: AppColors.textHint)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final notifier = ref.read(
                  projectDetailProvider(widget.projectId).notifier,
                );
                final success = await notifier.updateProject({
                  'progress': sliderValue.round(),
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Progress updated to ${sliderValue.round()}%'
                            : 'Failed to update progress',
                      ),
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteProject),
        content: const Text(
          'This will mark the project as deleted. You can restore it later from the backend if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final notifier = ref.read(projectDetailProvider(widget.projectId).notifier);
    final success = await notifier.deleteProject();

    if (!mounted) return;
    if (success) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.projectDeleted)));
        context.go('/admin/dashboard');
      }
    } else {
      final error =
          ref.read(projectDetailProvider(widget.projectId)).error ??
          'Failed to delete project';
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }
}

/// The main dashboard card showing Engineer, Status, and Material Snapshot
class _HeroSection extends StatelessWidget {
  final ProjectModel project;
  final bool isAdmin;
  final VoidCallback onEditManager;
  final VoidCallback onEditProject;
  final VoidCallback onUpdateStatus;
  final VoidCallback? onUpdateProgress;

  const _HeroSection({
    required this.project,
    required this.isAdmin,
    required this.onEditManager,
    required this.onEditProject,
    required this.onUpdateStatus,
    this.onUpdateProgress,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM yyyy');
    final assignedManagers =
        project.assignments ?? const <ProjectAssignmentModel>[];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: overline + edit ──
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: project.status.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isAdmin ? onUpdateStatus : null,
                      child: Text(
                        project.status.displayName.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: project.status.color,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    if (project.projectType != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '·',
                        style: TextStyle(
                          color: AppColors.borderDark,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        project.projectType!.value.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isAdmin)
                InkWell(
                  onTap: onEditProject,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Editorial project name ──
          Text(
            project.name,
            style: GoogleFonts.fraunces(
              fontSize: 30,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          if (project.clientName != null &&
              project.clientName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              project.clientName!,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ],

          // ── Meta row (location, completion) ──
          if (project.location != null || project.endDate != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                if (project.location != null)
                  _HeroMetaItem(
                    icon: Icons.location_on_outlined,
                    text: project.location!,
                  ),
                if (project.endDate != null)
                  _HeroMetaItem(
                    icon: Icons.calendar_today_outlined,
                    text: 'Due ${dateFormat.format(project.endDate!)}',
                  ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 18),

          // ── Progress ──
          GestureDetector(
            onTap: onUpdateProgress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'COMPLETION',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${project.progress}',
                      style: GoogleFonts.fraunces(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                        letterSpacing: -0.6,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, top: 6),
                      child: Text(
                        '%',
                        style: GoogleFonts.fraunces(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.primary,
                          height: 1,
                        ),
                      ),
                    ),
                    if (onUpdateProgress != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (project.progress.clamp(0, 100)) / 100,
                    minHeight: 5,
                    backgroundColor: AppColors.borderLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Assigned managers ──
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'TEAM',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                assignedManagers.isEmpty
                    ? 'Unassigned'
                    : '${assignedManagers.length} '
                        '${assignedManagers.length == 1 ? "manager" : "managers"}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isAdmin)
                InkWell(
                  onTap: onEditManager,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_add_alt_1,
                          size: 13,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Assign',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (assignedManagers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assignedManagers
                  .map(
                    (a) => _AssignedManagerChip(
                      name: a.userName ?? 'Unknown',
                      phone: a.userPhone,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroMetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _AssignedManagerChip extends StatelessWidget {
  final String name;
  final String? phone;

  const _AssignedManagerChip({required this.name, this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnPrimary,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            phone == null || phone!.isEmpty ? name : '$name · $phone',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation Modules (Vertical List)
class _ModuleNavigation extends StatelessWidget {
  final String projectId;
  const _ModuleNavigation({required this.projectId});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleNavCard(
        title: 'Blueprints',
        subtitle: 'Project documents / drawings',
        icon: Icons.description_outlined,
        color: const Color(0xFFE8F0FE),
        iconColor: const Color(0xFF1967D2),
        onTap: () => context.goNamed(
          'project-blueprints',
          pathParameters: {'id': projectId},
        ),
      ),
      _ModuleNavCard(
        title: 'Operations',
        subtitle: 'Consumption and expenses',
        icon: Icons.engineering_outlined,
        color: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1565C0),
        onTap: () => context.goNamed(
          'project-operations',
          pathParameters: {'id': projectId},
        ),
      ),
      _ModuleNavCard(
        title: 'Reports / Insights',
        subtitle: 'Bills and reports',
        icon: Icons.analytics_outlined,
        color: const Color(0xFFF3E5F5),
        iconColor: const Color(0xFF7B1FA2),
        onTap: () => context.goNamed(
          'project-reports',
          pathParameters: {'id': projectId},
        ),
      ),
      _ModuleNavCard(
        title: 'Site Photos',
        subtitle: 'Progress documentation',
        icon: Icons.photo_library_outlined,
        color: const Color(0xFFFFF3E0),
        iconColor: const Color(0xFFE65100),
        onTap: () => context.goNamed(
          'project-photos',
          pathParameters: {'id': projectId},
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 820;

        if (!useGrid) {
          return Column(
            children: [
              for (var i = 0; i < modules.length; i++) ...[
                modules[i],
                if (i != modules.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 120,
          ),
          itemBuilder: (context, index) => modules[index],
        );
      },
    );
  }
}

class _ModuleNavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ModuleNavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.1,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    color: AppColors.textHint, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

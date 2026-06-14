import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/project_model.dart';
import '../providers/project_provider.dart';

class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(projectListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectListProvider);
    final role = ref.watch(userRoleProvider);
    final isAdmin = role == UserRole.admin || role == UserRole.superAdmin;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final r = R(Size(constraints.maxWidth, constraints.maxHeight));

          return SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    r.isDesktop ? 32 : 20,
                    r.isDesktop ? 28 : 8,
                    r.isDesktop ? 32 : 20,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: r.maxContentWidth),
                      child: _buildHeader(context, state, isAdmin, r),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Content
                Expanded(child: _buildContent(state, isAdmin, r)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ProjectListState state,
    bool isAdmin,
    R r,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Editorial overline + count
        Row(
          children: [
            Text(
              'PORTFOLIO',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryDark,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.borderDark,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${state.projects.length} active',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Serif title + actions
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Projects',
                style: GoogleFonts.fraunces(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.0,
                  height: 1.05,
                ),
              ),
            ),
            if (isAdmin) ...[
              Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => _showFilterSheet(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: state.statusFilter != null
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => context.push('/projects/create'),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 20, color: AppColors.textOnPrimary),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),

        // Search + active filter
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search projects...',
                    hintStyle: TextStyle(
                        color: AppColors.textHint, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(projectListProvider.notifier)
                                  .search('');
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  onChanged: (value) {
                    setState(() {});
                    ref.read(projectListProvider.notifier).search(value);
                  },
                ),
              ),
            ),
            if (state.statusFilter != null) ...[
              const SizedBox(width: 10),
              Chip(
                label: Text(
                  state.statusFilter!.displayName,
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => ref
                    .read(projectListProvider.notifier)
                    .filterByStatus(null),
                backgroundColor: state.statusFilter!.color
                    .withValues(alpha: 0.1),
                side: BorderSide(
                    color:
                        state.statusFilter!.color.withValues(alpha: 0.3)),
                labelStyle: TextStyle(
                  color: state.statusFilter!.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildContent(ProjectListState state, bool isAdmin, R r) {
    if (state.isLoading && state.projects.isEmpty) {
      return const LoadingWidget(message: 'Loading projects...');
    }

    if (state.error != null && state.projects.isEmpty) {
      return AppErrorWidget(
        message: state.error!,
        onRetry: () => ref.read(projectListProvider.notifier).refresh(),
      );
    }

    if (state.projects.isEmpty) {
      return EmptyStateWidget(
        message: isAdmin
            ? 'No projects found.\nCreate your first project!'
            : 'No projects assigned to you yet.',
        icon: Icons.folder_open,
        action: isAdmin
            ? ElevatedButton.icon(
                onPressed: () => context.push('/projects/create'),
                icon: const Icon(Icons.add),
                label: const Text('Create Project'),
              )
            : null,
      );
    }

    final columns = r.w >= 1180
        ? 3
        : r.w >= 760
            ? 2
            : 1;

    return RefreshIndicator(
      onRefresh: () => ref.read(projectListProvider.notifier).refresh(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: columns == 1
              ? ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: r.isDesktop ? 32 : 20,
                    vertical: 8,
                  ),
                  itemCount:
                      state.projects.length + (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.projects.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _ProjectCard(
                      project: state.projects[index],
                      onTap: () => context
                          .push('/projects/${state.projects[index].id}'),
                    );
                  },
                )
              : GridView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: r.isDesktop ? 32 : 20,
                    vertical: 8,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 200,
                  ),
                  itemCount:
                      state.projects.length + (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.projects.length) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    return _ProjectCard(
                      project: state.projects[index],
                      onTap: () => context
                          .push('/projects/${state.projects[index].id}'),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterSheet(
        currentFilter: ref.read(projectListProvider).statusFilter,
        onFilterSelected: (status) {
          ref.read(projectListProvider.notifier).filterByStatus(status);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Project Card ──

class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = project.status.color;
    final progressColor = _getProgressColor(project.progress);

    final typeColor = project.projectType?.color ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top: monogram + title + budget ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProjectMonogram(
                      name: project.name,
                      color: typeColor,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: GoogleFonts.fraunces(
                              fontSize: 19,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                              height: 1.18,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (project.clientName != null &&
                              project.clientName!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              project.clientName!,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (project.budget != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        CurrencyFormatter.formatIndian(project.budget!),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                          height: 1.4,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),

                // ── Status + type ──
                Row(
                  children: [
                    _StatusPill(
                      label: project.status.displayName,
                      color: statusColor,
                    ),
                    if (project.projectType != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '·',
                        style: TextStyle(
                          color: AppColors.borderDark,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
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

                const SizedBox(height: 14),

                // Meta row
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (project.location != null)
                      _MetaItem(
                        icon: Icons.location_on_outlined,
                        text: project.location!,
                      ),
                    if (project.startDate != null)
                      _MetaItem(
                        icon: Icons.calendar_today_outlined,
                        text: DateFormat('MMM d, yyyy')
                            .format(project.startDate!),
                      ),
                    if (project.assignments != null &&
                        project.assignments!.isNotEmpty)
                      _MetaItem(
                        icon: Icons.people_outline_rounded,
                        text: '${project.assignments!.length} '
                            '${project.assignments!.length == 1 ? "manager" : "managers"}',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Hairline divider
                Container(
                  height: 1,
                  color: AppColors.borderLight,
                ),
                const SizedBox(height: 14),

                // Progress
                Row(
                  children: [
                    Text(
                      'Progress',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHint,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${project.progress}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: progressColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: project.progress / 100,
                    backgroundColor: AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(int progress) {
    if (progress < 25) return AppColors.error;
    if (progress < 50) return AppColors.warning;
    if (progress < 75) return AppColors.info;
    return AppColors.success;
  }
}

// ── Project Monogram ──
//
// A square tile with a serif initial — the recognition anchor for a
// project card when no cover photo is available.

class _ProjectMonogram extends StatelessWidget {
  final String name;
  final Color color;

  const _ProjectMonogram({required this.name, required this.color});

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

// ── Status Pill (editorial) ──

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Filter Sheet ──

class _FilterSheet extends StatelessWidget {
  final ProjectStatus? currentFilter;
  final Function(ProjectStatus?) onFilterSelected;

  const _FilterSheet({this.currentFilter, required this.onFilterSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Status',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _FilterOption(
              label: 'All Projects',
              isSelected: currentFilter == null,
              onTap: () => onFilterSelected(null),
            ),
            const Divider(),
            ...ProjectStatus.values.map(
              (status) => _FilterOption(
                label: status.displayName,
                isSelected: currentFilter == status,
                onTap: () => onFilterSelected(status),
                color: status.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: color != null
          ? Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
      contentPadding: EdgeInsets.zero,
    );
  }
}

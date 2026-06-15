import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/rera_report.dart';
import '../data/repositories/rera_pdf_export.dart';
import '../providers/rera_providers.dart';
import '../widgets/rera_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// RERA Quarterly Reporting dashboard.
///
/// Lists all quarterly filings for the current company, shows fund/status
/// aggregates, and is the entry point for creating, editing, exporting, and
/// viewing the geotagged photo timeline for each report.
class ReraDashboardScreen extends ConsumerWidget {
  const ReraDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportsAsync = ref.watch(reraReportsProvider);
    final stats = ref.watch(reraDashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.reraReporting),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(reraReportsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.pushNamed('rera-report-new');
          ref.invalidate(reraReportsProvider);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.newReport),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reraReportsProvider),
        child: reportsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: ReraPlaceholder(
                  icon: Icons.cloud_off_rounded,
                  title: "Couldn't load reports",
                  message: e.toString(),
                  action: OutlinedButton(
                    onPressed: () => ref.invalidate(reraReportsProvider),
                    child: Text(l10n.retry),
                  ),
                ),
              ),
            ],
          ),
          data: (reports) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: _StatsSection(stats: stats),
                ),
              ),
              if (reports.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ReraPlaceholder(
                    icon: Icons.description_outlined,
                    title: 'No RERA reports yet',
                    message:
                        'Create your first quarterly progress report to start '
                        'tracking completion and project funds.',
                    action: FilledButton.icon(
                      onPressed: () async {
                        await context.pushNamed('rera-report-new');
                        ref.invalidate(reraReportsProvider);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.newReport),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s16),
                  sliver: SliverList.separated(
                    itemCount: reports.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.s3),
                    itemBuilder: (context, i) => _ReportCard(
                      report: reports[i],
                      onChanged: () => ref.invalidate(reraReportsProvider),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final AsyncValue<ReraDashboardStats> stats;
  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ReraStatTile(
                  label: 'Total reports',
                  value: '${s.totalReports}',
                  icon: Icons.folder_copy_outlined,
                  accent: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ReraStatTile(
                  label: 'Submitted',
                  value: '${s.submittedCount}',
                  icon: Icons.send_outlined,
                  accent: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ReraStatTile(
                  label: 'Approved',
                  value: '${s.approvedCount}',
                  icon: Icons.verified_outlined,
                  accent: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: ReraStatTile(
                  label: 'Funds received',
                  value: formatReraInr(s.totalFundsReceived),
                  icon: Icons.south_west_rounded,
                  accent: AppColors.success,
                  mono: true,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ReraStatTile(
                  label: 'Funds utilized',
                  value: formatReraInr(s.totalFundsUtilized),
                  icon: Icons.north_east_rounded,
                  accent: AppColors.accent,
                  mono: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final ReraReport report;
  final VoidCallback onChanged;
  const _ReportCard({required this.report, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.projectName ?? 'Project',
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.periodLabel,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ReraStatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            ReraProgressBar(pct: report.completionPct),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: _FundMini(
                    label: 'Received',
                    value: formatReraInr(report.fundsReceived),
                    color: AppColors.success,
                  ),
                ),
                Expanded(
                  child: _FundMini(
                    label: 'Utilized',
                    value: formatReraInr(report.fundsUtilized),
                    color: AppColors.accent,
                  ),
                ),
                Expanded(
                  child: _FundMini(
                    label: 'Balance',
                    value: formatReraInr(report.fundsBalance),
                    color: report.fundsBalance < 0
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.s6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await context.pushNamed(
                      'rera-report-edit',
                      pathParameters: {'id': report.id},
                    );
                    onChanged();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.edit),
                ),
                TextButton.icon(
                  onPressed: () => context.pushNamed(
                    'rera-photo-timeline',
                    pathParameters: {'projectId': report.projectId},
                    queryParameters: {
                      if (report.projectName != null)
                        'name': report.projectName!,
                    },
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(l10n.photos),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => ReraPdfExport.exportQuarterlyReport(report),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FundMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FundMini(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.mono
              .copyWith(color: color, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

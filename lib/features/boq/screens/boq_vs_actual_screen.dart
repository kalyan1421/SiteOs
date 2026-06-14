import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/boq_vs_actual_row.dart';
import '../providers/boq_providers.dart';
import '../widgets/boq_money_text.dart';

/// Compares a BOQ's estimate (per category) against actual material
/// consumption for its project — a read-only join of `boq_items` (estimate)
/// vs outward `material_logs` x `stock_items` (actual). When the actual source
/// has no matching data the actual columns show "—" and a TODO note explains
/// why.
///
/// Route: /projects/:projectId/boq/:boqId/vs-actual
class BoqVsActualScreen extends ConsumerWidget {
  final String projectId;
  final String boqId;
  final String? projectName;
  final String? boqName;

  const BoqVsActualScreen({
    super.key,
    required this.projectId,
    required this.boqId,
    this.projectName,
    this.boqName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = BoqVsActualArgs(boqId: boqId, projectId: projectId);
    final rowsAsync = ref.watch(boqVsActualProvider(args));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('BOQ vs Actual', style: AppTextStyles.titleLarge),
            if ((boqName ?? '').isNotEmpty)
              Text(
                boqName!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(boqVsActualProvider(args)),
        child: rowsAsync.when(
          data: (rows) => rows.isEmpty ? _empty() : _content(rows),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _error(
            e.toString(),
            () => ref.invalidate(boqVsActualProvider(args)),
          ),
        ),
      ),
    );
  }

  Widget _content(List<BoqVsActualRow> rows) {
    final estimateTotal =
        rows.fold<double>(0, (sum, r) => sum + r.estimateAmount);
    final actualTotal = rows.fold<double>(
        0, (sum, r) => sum + (r.actualAmount ?? 0));
    final anyActualKnown = rows.any((r) => !r.actualUnknown);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s8),
      children: [
        _SummaryCard(
          estimateTotal: estimateTotal,
          actualTotal: anyActualKnown ? actualTotal : null,
        ),
        const SizedBox(height: AppSpacing.s4),
        if (!anyActualKnown) ...[
          const _ActualTodoBanner(),
          const SizedBox(height: AppSpacing.s4),
        ],
        Text('BY CATEGORY', style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.s2),
        for (final row in rows) ...[
          _CategoryComparisonCard(row: row),
          const SizedBox(height: AppSpacing.s3),
        ],
      ],
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s8),
      children: [
        const SizedBox(height: AppSpacing.s16),
        const Icon(Icons.compare_arrows_rounded,
            size: 56, color: AppColors.textDisabled),
        const SizedBox(height: AppSpacing.s4),
        Text('Nothing to compare yet',
            style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Add line items to this BOQ and record material consumption on the '
          'project to see estimate-vs-actual figures here.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _error(String message, VoidCallback onRetry) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s8),
      children: [
        const SizedBox(height: AppSpacing.s12),
        const Icon(Icons.error_outline_rounded,
            size: 48, color: AppColors.error),
        const SizedBox(height: AppSpacing.s4),
        Text("Couldn't load comparison",
            style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s2),
        Text(message,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s4),
        Center(
          child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

/// Top-of-page roll-up: estimate vs actual totals and overall variance.
class _SummaryCard extends StatelessWidget {
  final double estimateTotal;

  /// Null when no actual consumption could be resolved for any category.
  final double? actualTotal;

  const _SummaryCard({required this.estimateTotal, this.actualTotal});

  @override
  Widget build(BuildContext context) {
    final variance =
        actualTotal == null ? null : actualTotal! - estimateTotal;
    final over = variance != null && variance > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                child: _TotalBlock(
                  label: 'ESTIMATE',
                  value: estimateTotal,
                  color: AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              ),
              Expanded(
                child: actualTotal == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ACTUAL', style: AppTextStyles.overline),
                          const SizedBox(height: 4),
                          Text('—',
                              style: AppTextStyles.price
                                  .copyWith(color: AppColors.textHint)),
                        ],
                      )
                    : _TotalBlock(
                        label: 'ACTUAL',
                        value: actualTotal!,
                        color: AppColors.secondaryDark,
                      ),
              ),
            ],
          ),
          if (variance != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
              decoration: BoxDecoration(
                color: over ? AppColors.errorLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        over
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 18,
                        color: over
                            ? AppColors.errorDark
                            : AppColors.successDark,
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        over ? 'Over estimate' : 'Under estimate',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: over
                              ? AppColors.errorDark
                              : AppColors.successDark,
                        ),
                      ),
                    ],
                  ),
                  BoqMoneyText(
                    variance.abs(),
                    weight: FontWeight.w700,
                    color:
                        over ? AppColors.errorDark : AppColors.successDark,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalBlock extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _TotalBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.overline),
        const SizedBox(height: 4),
        BoqMoneyText.large(value, color: color),
      ],
    );
  }
}

/// Per-category card: estimate qty/amount vs actual qty/amount + variance.
class _CategoryComparisonCard extends StatelessWidget {
  final BoqVsActualRow row;

  const _CategoryComparisonCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final pct = row.amountVariancePct;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.category, style: AppTextStyles.titleMedium),
              ),
              if (row.actualUnknown)
                _Pill(
                  label: 'No actual',
                  color: AppColors.textHint,
                  background: AppColors.surfaceVariant,
                )
              else if (pct != null)
                _Pill(
                  label:
                      '${pct >= 0 ? '+' : ''}${(pct * 100).toStringAsFixed(1)}%',
                  color: row.isOverBudget
                      ? AppColors.errorDark
                      : AppColors.successDark,
                  background: row.isOverBudget
                      ? AppColors.errorLight
                      : AppColors.successLight,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Est. qty',
                  text: _qty(row.estimateQty),
                  mono: true,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Est. amount',
                  amount: row.estimateAmount,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Actual qty',
                  text: row.actualQty == null ? '—' : _qty(row.actualQty!),
                  mono: true,
                  muted: row.actualUnknown,
                ),
              ),
              Expanded(
                child: row.actualAmount == null
                    ? _Metric(label: 'Actual amount', text: '—', muted: true)
                    : _Metric(
                        label: 'Actual amount',
                        amount: row.actualAmount!,
                        amountColor: AppColors.secondaryDark,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _qty(double v) {
    final s = v.toStringAsFixed(3);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }
}

/// A small labelled metric — either a ₹ amount (mono via [BoqMoneyText]) or
/// a plain/mono text value.
class _Metric extends StatelessWidget {
  final String label;
  final String? text;
  final double? amount;
  final Color? amountColor;
  final bool mono;
  final bool muted;

  const _Metric({
    required this.label,
    this.text,
    this.amount,
    this.amountColor,
    this.mono = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textHint)),
        const SizedBox(height: 2),
        if (amount != null)
          BoqMoneyText(
            amount!,
            weight: FontWeight.w600,
            color: amountColor ?? AppColors.textPrimary,
          )
        else
          Text(
            text ?? '—',
            style: (mono ? AppTextStyles.mono : AppTextStyles.bodyMedium)
                .copyWith(
              color: muted ? AppColors.textHint : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _Pill({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Explains why actual figures are blank when no consumption source matched.
class _ActualTodoBanner extends StatelessWidget {
  const _ActualTodoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 20, color: AppColors.warningDark),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actual consumption not available',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.warningDark),
                ),
                const SizedBox(height: 2),
                Text(
                  'No outward material logs were found for this project. '
                  'Actuals are derived from outward stock movements '
                  '(material_logs) joined to stock item categories — '
                  'showing estimate columns only for now.',
                  // TODO(AKS-72): once category mapping between BOQ categories
                  // and stock item categories is finalised, reconcile units so
                  // qty variance is apples-to-apples per line.
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.warningDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

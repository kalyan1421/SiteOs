import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/subcontractor_model.dart';
import '../data/models/work_order_model.dart';
import '../providers/subcontractor_providers.dart';
import '../widgets/money_text.dart';
import '../widgets/status_chip.dart';
import 'sub_ra_bill_screen.dart';
import 'work_order_form.dart';

/// Work orders awarded to a single subcontractor. Tap a WO to open its RA
/// bills; the + button raises a new work order.
class WorkOrderScreen extends ConsumerWidget {
  final SubcontractorModel subcontractor;

  const WorkOrderScreen({super.key, required this.subcontractor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncWos = ref.watch(workOrdersProvider(subcontractor.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(subcontractor.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.s4,
              bottom: AppSpacing.s2,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Work Orders',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textOnPrimary),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New WO'),
      ),
      body: asyncWos.when(
        data: (wos) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(workOrdersProvider(subcontractor.id)),
          child: wos.isEmpty
              ? _Empty()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  itemCount: wos.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.s3),
                  itemBuilder: (_, i) => _WorkOrderCard(
                    workOrder: wos[i],
                    onTap: () => _openBills(context, wos[i]),
                    onEdit: () => _openForm(context, ref, existing: wos[i]),
                  ),
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Error(
          message: '$e',
          onRetry: () =>
              ref.invalidate(workOrdersProvider(subcontractor.id)),
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    WorkOrderModel? existing,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkOrderForm(
          subcontractor: subcontractor,
          existing: existing,
        ),
      ),
    );
  }

  void _openBills(BuildContext context, WorkOrderModel wo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubRaBillScreen(workOrder: wo),
      ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  final WorkOrderModel workOrder;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _WorkOrderCard({
    required this.workOrder,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final wo = workOrder;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wo.woNumber?.isNotEmpty == true
                          ? wo.woNumber!
                          : 'Work Order',
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusChip.workOrder(wo.status),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.textHint,
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                wo.scope,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (wo.projectName != null) ...[
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    const Icon(Icons.apartment_outlined,
                        size: 14, color: AppColors.textHint),
                    const SizedBox(width: AppSpacing.s1),
                    Expanded(
                      child: Text(
                        wo.projectName!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: AppSpacing.s5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order value',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textHint)),
                      MoneyText(wo.value),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Retention ${_pct(wo.retentionPct)}',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textHint)),
                      MoneyText(
                        wo.retentionAmount,
                        color: AppColors.warningDark,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _pct(double v) =>
      v == v.roundToDouble() ? '${v.toStringAsFixed(0)}%' : '$v%';
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.s16),
        const Icon(Icons.assignment_outlined,
            size: 56, color: AppColors.textHint),
        const SizedBox(height: AppSpacing.s4),
        Text('No work orders yet',
            textAlign: TextAlign.center, style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Award a scope of work to start raising RA bills.',
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
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: AppSpacing.s4),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

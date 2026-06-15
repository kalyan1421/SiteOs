import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/boq_category_group.dart';
import '../data/models/boq_item_model.dart';
import '../data/services/boq_pdf_service.dart';
import '../providers/boq_providers.dart';
import '../widgets/boq_money_text.dart';
import 'boq_item_form.dart';

/// Shows one BOQ: its line items grouped into a category accordion with
/// per-category subtotals and a sticky grand total. Supports adding items,
/// exporting the PDF abstract sheet, and opening BOQ-vs-Actual.
///
/// Route: /projects/:projectId/boq/:boqId
class BoqDetailScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String boqId;
  final String? projectName;
  final String? boqName;

  const BoqDetailScreen({
    super.key,
    required this.projectId,
    required this.boqId,
    this.projectName,
    this.boqName,
  });

  @override
  ConsumerState<BoqDetailScreen> createState() => _BoqDetailScreenState();
}

class _BoqDetailScreenState extends ConsumerState<BoqDetailScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(boqItemsProvider(widget.boqId));
    final headerAsync = ref.watch(boqHeaderProvider(widget.boqId));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          widget.boqName ?? headerAsync.valueOrNull?.name ?? 'BOQ',
          style: AppTextStyles.titleLarge,
        ),
        actions: [
          IconButton(
            tooltip: 'BOQ vs Actual',
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: () => context.push(
              '/projects/${widget.projectId}/boq/${widget.boqId}/vs-actual',
              extra: {
                'projectName': widget.projectName,
                'boqName': widget.boqName ?? headerAsync.valueOrNull?.name,
              },
            ),
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting ? null : () => _exportPdf(itemsAsync.valueOrNull),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddItem(itemsAsync.valueOrNull ?? const []),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addItem),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(boqItemsProvider(widget.boqId));
          ref.invalidate(boqHeaderProvider(widget.boqId));
        },
        child: itemsAsync.when(
          data: (items) =>
              items.isEmpty ? _empty() : _content(items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _error(e.toString()),
        ),
      ),
    );
  }

  Widget _content(List<BoqItemModel> items) {
    final groups = groupBoqItemsByCategory(items);
    final grandTotal = boqGrandTotal(items);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s4),
            children: [
              for (final group in groups)
                _CategoryAccordion(
                  group: group,
                  onDeleteItem: (item) => _deleteItem(item),
                ),
            ],
          ),
        ),
        _GrandTotalBar(total: grandTotal, lineCount: items.length),
      ],
    );
  }

  Widget _empty() {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s8),
      children: [
        const SizedBox(height: AppSpacing.s16),
        const Icon(Icons.playlist_add_rounded,
            size: 56, color: AppColors.textDisabled),
        const SizedBox(height: AppSpacing.s4),
        Text(l10n.noLineItemsYet,
            style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Add items grouped by category (Earthwork, Concrete, Steel…) '
          'to build up this estimate.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s5),
        Center(
          child: FilledButton.icon(
            onPressed: () => _openAddItem(const []),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.addFirstItem),
          ),
        ),
      ],
    );
  }

  Widget _error(String message) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s8),
      children: [
        const SizedBox(height: AppSpacing.s12),
        const Icon(Icons.error_outline_rounded,
            size: 48, color: AppColors.error),
        const SizedBox(height: AppSpacing.s4),
        Text("Couldn't load items",
            style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s2),
        Text(message,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s4),
        Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(boqItemsProvider(widget.boqId)),
            child: Text(l10n.retry),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddItem(List<BoqItemModel> currentItems) async {
    final categories = groupBoqItemsByCategory(currentItems)
        .map((g) => g.category)
        .toList();
    final added = await showModalBottomSheet<bool>(
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
        child: BoqItemForm(
          boqId: widget.boqId,
          existingCategories: categories,
        ),
      ),
    );
    if (added == true) {
      ref.invalidate(boqItemsProvider(widget.boqId));
      ref.invalidate(boqHeaderProvider(widget.boqId));
    }
  }

  Future<void> _deleteItem(BoqItemModel item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete line item?'),
        content: Text(item.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(boqRepositoryProvider).deleteItem(item.id);
      ref.invalidate(boqItemsProvider(widget.boqId));
      ref.invalidate(boqHeaderProvider(widget.boqId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf(List<BoqItemModel>? items) async {
    if (items == null || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add line items before exporting.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final header = await ref.read(boqHeaderProvider(widget.boqId).future);
      await BoqPdfService().shareAbstractSheet(
        header: header,
        items: items,
        projectName: widget.projectName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _CategoryAccordion extends StatelessWidget {
  final BoqCategoryGroup group;
  final void Function(BoqItemModel item) onDeleteItem;

  const _CategoryAccordion({required this.group, required this.onDeleteItem});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4, vertical: AppSpacing.s1),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Expanded(
                child: Text(group.category, style: AppTextStyles.titleMedium),
              ),
              Text('${group.itemCount} item${group.itemCount == 1 ? '' : 's'}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textHint)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text('${l10n.subtotal}  ',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                BoqMoneyText(
                  group.subtotal,
                  weight: FontWeight.w600,
                  color: AppColors.secondaryDark,
                ),
              ],
            ),
          ),
          children: [
            for (final item in group.items)
              _LineItemRow(item: item, onDelete: () => onDeleteItem(item)),
            const SizedBox(height: AppSpacing.s2),
          ],
        ),
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final BoqItemModel item;
  final VoidCallback onDelete;

  const _LineItemRow({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '${_qty(item.qty)} ${item.unit} × ${_money(item.rate)}',
                  style: AppTextStyles.mono.copyWith(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BoqMoneyText(item.computedAmount, weight: FontWeight.w600),
              const SizedBox(height: 2),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.textHint),
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

  static String _money(double v) => '₹${v.toStringAsFixed(2)}';
}

class _GrandTotalBar extends StatelessWidget {
  final double total;
  final int lineCount;

  const _GrandTotalBar({required this.total, required this.lineCount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s5, AppSpacing.s4, AppSpacing.s5, AppSpacing.s5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppElevation.lg,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.grandTotal, style: AppTextStyles.overline),
                const SizedBox(height: 2),
                Text('$lineCount line item${lineCount == 1 ? '' : 's'}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint)),
              ],
            ),
            BoqMoneyText.large(total, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

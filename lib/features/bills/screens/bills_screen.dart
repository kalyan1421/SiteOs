import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/upload_helper.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/bill_model.dart';
import '../providers/bill_provider.dart';
import '../widgets/bill_approval_sheet.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _dateRange;
  BillType? _filterType;
  PaymentStatus? _filterPaymentStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) setState(() {});
  }

  bool get _showCompletedTab => _tabController.index == 1;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _dateRange != null || _filterType != null || _filterPaymentStatus != null;

  void _clearAllFilters() {
    setState(() {
      _dateRange = null;
      _filterType = null;
      _filterPaymentStatus = null;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Future<void> _showFilterSheet() async {
    final l10n = AppLocalizations.of(context)!;
    BillType? tmpType = _filterType;
    PaymentStatus? tmpPaymentStatus = _filterPaymentStatus;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.filterBills,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setSheet(() {
                        tmpType = null;
                        tmpPaymentStatus = null;
                      });
                    },
                    child: Text(l10n.clearAll),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.billType,
                  style: Theme.of(ctx)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BillType.values.map((t) {
                  final selected = tmpType == t;
                  return FilterChip(
                    label: Text(t.label),
                    selected: selected,
                    onSelected: (v) =>
                        setSheet(() => tmpType = v ? t : null),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(l10n.paymentStatus,
                  style: Theme.of(ctx)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PaymentStatus.values.map((s) {
                  final selected = tmpPaymentStatus == s;
                  return FilterChip(
                    label: Text(s.label),
                    selected: selected,
                    onSelected: (v) =>
                        setSheet(() => tmpPaymentStatus = v ? s : null),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterType = tmpType;
                      _filterPaymentStatus = tmpPaymentStatus;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(l10n.applyFilters),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.role;
    final isSiteManager = role == UserRole.siteManager;
    final isAdmin = role == UserRole.admin || role == UserRole.superAdmin;

    final billsAsync = ref.watch(dashboardBillsCombinedProvider(isSiteManager));
    final billsData = billsAsync.valueOrNull ?? const <BillModel>[];
    final pendingCount =
        billsData.where((b) => !b.status.isCompleted).length;
    final completedCount =
        billsData.where((b) => b.status.isCompleted).length;

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
                      child: _buildHeader(
                        context,
                        r: r,
                        isAdmin: isAdmin,
                        isSiteManager: isSiteManager,
                        pendingCount: pendingCount,
                        completedCount: completedCount,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: billsAsync.when(
                    data: (bills) {
                      final filtered = bills.where((bill) {
                        if (_dateRange != null) {
                          final d = DateTime(
                              bill.billDate.year, bill.billDate.month, bill.billDate.day);
                          final start = DateTime(_dateRange!.start.year,
                              _dateRange!.start.month, _dateRange!.start.day);
                          final end = DateTime(_dateRange!.end.year,
                              _dateRange!.end.month, _dateRange!.end.day);
                          if (d.isBefore(start) || d.isAfter(end)) return false;
                        }
                        if (_filterType != null && bill.type != _filterType) {
                          return false;
                        }
                        if (_filterPaymentStatus != null &&
                            bill.paymentStatus != _filterPaymentStatus) {
                          return false;
                        }
                        return _showCompletedTab
                            ? bill.status.isCompleted
                            : !bill.status.isCompleted;
                      }).toList()
                        ..sort(
                            (a, b) => b.billDate.compareTo(a.billDate));

                      return _buildBillList(
                        bills: filtered,
                        isAdmin: isAdmin,
                        isSiteManager: isSiteManager,
                        r: r,
                      );
                    },
                    loading: () =>
                        const LoadingWidget(message: 'Loading bills...'),
                    error: (err, _) => AppErrorWidget(
                      message: err.toString(),
                      onRetry: _refreshBillData,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader(
    BuildContext context, {
    required R r,
    required bool isAdmin,
    required bool isSiteManager,
    required int pendingCount,
    required int completedCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Editorial overline
        Row(
          children: [
            Text(
              'EXPENSES',
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
              '$pendingCount pending',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Title row + filter actions
        Row(
          children: [
            Expanded(
              child: Text(
                'Bills',
                style: GoogleFonts.fraunces(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.0,
                  height: 1.05,
                ),
              ),
            ),
            _DateRangeChip(
              dateRange: _dateRange,
              onTap: _pickDateRange,
              onClear: () => setState(() => _dateRange = null),
            ),
            const SizedBox(width: 8),
            _FilterIconButton(
              hasActiveFilters: _filterType != null || _filterPaymentStatus != null,
              onTap: _showFilterSheet,
            ),
            // On desktop keep action buttons in the same row
            if (r.isDesktop && (isSiteManager || isAdmin)) ...[
              const SizedBox(width: 8),
              _HeaderButton(
                icon: Icons.add_rounded,
                label: 'New',
                filled: true,
                onTap: () => context.push('/bills/create'),
              ),
            ],
            if (r.isDesktop && isAdmin) ...[
              const SizedBox(width: 8),
              _HeaderButton(
                icon: Icons.checklist_rounded,
                label: 'Queue',
                filled: false,
                onTap: () => context.push('/bills/approval-queue'),
              ),
            ],
          ],
        ),
        // On mobile: action buttons on their own row
        if (!r.isDesktop && (isSiteManager || isAdmin)) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _HeaderButton(
                icon: Icons.add_rounded,
                label: 'New',
                filled: true,
                onTap: () => context.push('/bills/create'),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                _HeaderButton(
                  icon: Icons.checklist_rounded,
                  label: 'Queue',
                  filled: false,
                  onTap: () => context.push('/bills/approval-queue'),
                ),
              ],
            ],
          ),
        ],
        if (_hasActiveFilters) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (_dateRange != null)
                _ActiveFilterChip(
                  label: '${DateFormat('dd MMM').format(_dateRange!.start)} – ${DateFormat('dd MMM').format(_dateRange!.end)}',
                  onRemove: () => setState(() => _dateRange = null),
                ),
              if (_filterType != null)
                _ActiveFilterChip(
                  label: _filterType!.label,
                  onRemove: () => setState(() => _filterType = null),
                ),
              if (_filterPaymentStatus != null)
                _ActiveFilterChip(
                  label: _filterPaymentStatus!.label,
                  onRemove: () => setState(() => _filterPaymentStatus = null),
                ),
              const Spacer(),
              TextButton(
                onPressed: _clearAllFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear all',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),

        // Tab bar — refined segmented control
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            dividerColor: Colors.transparent,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
            padding: const EdgeInsets.all(3),
            tabs: [
              Tab(child: Text('Pending  $pendingCount')),
              Tab(child: Text('Completed  $completedCount')),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bill List ──

  Widget _buildBillList({
    required List<BillModel> bills,
    required bool isAdmin,
    required bool isSiteManager,
    required R r,
  }) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 28, color: AppColors.textHint),
            ),
            const SizedBox(height: 14),
            Text(
              _showCompletedTab ? 'No completed bills' : 'No pending bills',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<BillModel>>{};
    for (final bill in bills) {
      final key = _getDateKey(bill.billDate);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(bill);
    }

    final columns = r.w >= 1180
        ? 3
        : r.w >= 760
            ? 2
            : 1;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: r.isDesktop ? 32 : 20,
            vertical: 8,
          ),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final dateKey = grouped.keys.elementAt(index);
            final dateBills = grouped[dateKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  child: Text(
                    dateKey.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (columns == 1)
                  ...dateBills.map(
                    (bill) => _buildBillCard(
                      bill,
                      isAdmin: isAdmin,
                      isSiteManager: isSiteManager,
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dateBills.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 190,
                    ),
                    itemBuilder: (context, i) => _buildBillCard(
                      dateBills[i],
                      isAdmin: isAdmin,
                      isSiteManager: isSiteManager,
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBillCard(
    BillModel bill, {
    required bool isAdmin,
    required bool isSiteManager,
  }) {
    return _BillCard(
      bill: bill,
      onTap: isAdmin && !bill.status.isCompleted
          ? () => _showAdminApprovalDialog(bill)
          : null,
      canEdit: (isSiteManager && !bill.status.isCompleted) || isAdmin,
      canDelete: isAdmin,
      onMenuAction: (action) {
        switch (action) {
          case _BillMenuAction.edit:
            _showEditBillDialog(bill);
            break;
          case _BillMenuAction.delete:
            _confirmDeleteBill(bill);
            break;
        }
      },
    );
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) return 'Today';
    if (checkDate == yesterday) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  void _refreshBillData() {
    ref.invalidate(dashboardBillsProvider);
    ref.invalidate(dashboardBillsStreamProvider);
    ref.invalidate(dashboardBillsCombinedProvider);
    ref.invalidate(billsProvider);
    ref.invalidate(billsStreamProvider);
    ref.invalidate(billsCombinedProvider);
    ref.invalidate(paginatedPendingBillsProvider);
  }

  // ── Dialogs (unchanged logic) ──

  Future<void> _showEditBillDialog(BillModel bill) async {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController(text: bill.title);
    final amountController = TextEditingController(
      text: bill.amount.toStringAsFixed(2),
    );
    final vendorController = TextEditingController(text: bill.vendorName ?? '');
    final descriptionController = TextEditingController(
      text: bill.description ?? '',
    );

    BillType selectedType = bill.type;
    PaymentType selectedPaymentType = bill.paymentType ?? PaymentType.cash;
    PaymentStatus selectedPaymentStatus = bill.paymentStatus;
    DateTime selectedBillDate = bill.billDate;
    bool isSaving = false;

    // Receipt / attachment state
    List<int>? receiptBytes;
    String? receiptName;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> saveEdit() async {
                final title = titleController.text.trim();
                final amount = double.tryParse(amountController.text.trim());
                if (title.isEmpty || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.enterValidTitleAndAmount),
                    ),
                  );
                  return;
                }

                setModalState(() => isSaving = true);

                // Upload receipt if a new one was selected
                String? newReceiptUrl;
                if (receiptBytes != null && receiptName != null) {
                  try {
                    final relativePath = UploadHelper.generateUniquePath(
                      'receipts',
                      receiptName!,
                    );
                    final filePath = '${bill.projectId}/$relativePath';
                    newReceiptUrl = await UploadHelper.uploadWithRetry(
                      bucket: AppConstants.bucketBills,
                      path: filePath,
                      bytes: Uint8List.fromList(receiptBytes!),
                    );
                  } catch (e) {
                    if (!sheetContext.mounted) return;
                    setModalState(() => isSaving = false);
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Receipt upload failed: $e')),
                      );
                    }
                    return;
                  }
                }

                final success = await ref
                    .read(billControllerProvider.notifier)
                    .updateBill(
                      billId: bill.id,
                      updates: {
                        'title': title,
                        'amount': amount,
                        'bill_type': selectedType.value,
                        'vendor_name': vendorController.text.trim().isEmpty
                            ? null
                            : vendorController.text.trim(),
                        'description':
                            descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                        'payment_type': selectedPaymentType.value,
                        'payment_status': selectedPaymentStatus.value,
                        'bill_date': selectedBillDate
                            .toIso8601String()
                            .split('T')
                            .first,
                        if (newReceiptUrl != null) ...{
                          'receipt_url': newReceiptUrl,
                          'image_url': newReceiptUrl,
                        },
                      },
                    );
                if (sheetContext.mounted) {
                  setModalState(() => isSaving = false);
                }
                if (success) {
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  _refreshBillData();
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.billUpdatedSuccessfully),
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    final state = ref.read(billControllerProvider);
                    final errorMessage = state.hasError
                        ? state.error.toString()
                        : 'Failed to update bill';
                    ScaffoldMessenger.of(this.context)
                        .showSnackBar(SnackBar(content: Text(errorMessage)));
                  }
                }
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Bill',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Bill Title',
                          prefixIcon: Icon(Icons.receipt_long),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<BillType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Bill Type',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: BillType.values
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text(t.label)))
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (v) {
                                if (v != null) {
                                  setModalState(() => selectedType = v);
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<PaymentStatus>(
                        initialValue: selectedPaymentStatus,
                        decoration: const InputDecoration(
                          labelText: 'Payment Status',
                          prefixIcon: Icon(Icons.pending_actions_outlined),
                        ),
                        items: PaymentStatus.values
                            .map((s) => DropdownMenuItem(
                                value: s, child: Text(s.label)))
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (v) {
                                if (v != null) {
                                  setModalState(
                                      () => selectedPaymentStatus = v);
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<PaymentType>(
                        initialValue: selectedPaymentType,
                        decoration: const InputDecoration(
                          labelText: 'Payment Type',
                          prefixIcon:
                              Icon(Icons.account_balance_wallet_outlined),
                        ),
                        items: PaymentType.values
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(p.label)))
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (v) {
                                if (v != null) {
                                  setModalState(
                                      () => selectedPaymentType = v);
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: isSaving
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedBillDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setModalState(
                                      () => selectedBillDate = picked);
                                }
                              },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Bill Date',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(DateFormat('dd-MM-yyyy')
                              .format(selectedBillDate)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: vendorController,
                        decoration: const InputDecoration(
                          labelText: 'Vendor Name',
                          prefixIcon: Icon(Icons.store_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Receipt / Invoice attachment
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: isSaving
                            ? null
                            : () async {
                                await showModalBottomSheet<void>(
                                  context: context,
                                  builder: (ctx) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                                          title: Text(l10n.takePhoto),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
                                            if (picked == null) return;
                                            final bytes = await picked.readAsBytes();
                                            setModalState(() {
                                              receiptBytes = bytes;
                                              receiptName = picked.name;
                                            });
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                                          title: Text(l10n.chooseFromGallery),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                                            if (picked == null) return;
                                            final bytes = await picked.readAsBytes();
                                            setModalState(() {
                                              receiptBytes = bytes;
                                              receiptName = picked.name;
                                            });
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.attach_file_outlined, color: AppColors.primary),
                                          title: Text(l10n.browseFilesPdfImage),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            final result = await FilePicker.platform.pickFiles(
                                              type: FileType.custom,
                                              allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                                              withData: true,
                                            );
                                            if (result != null && result.files.single.bytes != null) {
                                              setModalState(() {
                                                receiptBytes = result.files.single.bytes;
                                                receiptName = result.files.single.name;
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: receiptName != null
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: receiptName != null
                                ? AppColors.primary.withValues(alpha: 0.05)
                                : AppColors.surfaceVariant
                                    .withValues(alpha: 0.4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                receiptName != null
                                    ? Icons.check_circle_outline
                                    : Icons.attach_file_rounded,
                                size: 20,
                                color: receiptName != null
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: receiptName != null
                                    ? Text(
                                        receiptName!,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : bill.receiptUrl != null
                                        ? Row(
                                            children: [
                                              Text(
                                                'Receipt attached',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.success
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Replace',
                                                  style: TextStyle(
                                                    color: AppColors.success,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            'Attach receipt / invoice (optional)',
                                            style: TextStyle(
                                              color: AppColors.textHint,
                                              fontSize: 13,
                                            ),
                                          ),
                              ),
                              if (receiptName != null)
                                GestureDetector(
                                  onTap: () => setModalState(() {
                                    receiptBytes = null;
                                    receiptName = null;
                                  }),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.textHint,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : saveEdit,
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text(l10n.saveChanges),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      amountController.dispose();
      vendorController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _confirmDeleteBill(BillModel bill) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteBill),
        content: Text('Delete "${bill.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final success = await ref
        .read(billControllerProvider.notifier)
        .softDeleteBill(bill.id);
    if (!mounted) return;

    if (success) _refreshBillData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Bill moved to Bin' : 'Failed to delete bill'),
      ),
    );
  }

  Future<void> _showAdminApprovalDialog(BillModel bill) {
    return BillApprovalSheet.show(
      context,
      bill: bill,
      onSuccess: _refreshBillData,
    );
  }
}

// ── Bill Card ──

class _BillCard extends StatelessWidget {
  final BillModel bill;
  final VoidCallback? onTap;
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<_BillMenuAction>? onMenuAction;

  const _BillCard({
    required this.bill,
    this.onTap,
    this.canEdit = false,
    this.canDelete = false,
    this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCompleted = bill.status.isCompleted;
    final statusColor =
        isCompleted ? AppColors.success : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: date + amount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd MMM · yyyy')
                                .format(bill.billDate)
                                .toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bill.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (bill.raisedByName != null ||
                              bill.createdByName != null ||
                              bill.vendorName != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              bill.raisedByName ??
                                  bill.createdByName ??
                                  bill.vendorName ??
                                  '',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatSimple(bill.amount),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                            height: 1.1,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (canEdit || canDelete)
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: PopupMenuButton<_BillMenuAction>(
                              icon: Icon(Icons.more_horiz_rounded,
                                  color: AppColors.textHint, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: onMenuAction,
                              itemBuilder: (_) {
                                final items =
                                    <PopupMenuEntry<_BillMenuAction>>[];
                                if (canEdit) {
                                  items.add(PopupMenuItem(
                                      value: _BillMenuAction.edit,
                                      child: Text(l10n.edit)));
                                }
                                if (canDelete) {
                                  items.add(PopupMenuItem(
                                      value: _BillMenuAction.delete,
                                      child: Text(l10n.delete)));
                                }
                                return items;
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),

                // Bottom: status pills
                Row(
                  children: [
                    _StatusDot(
                      label: isCompleted ? 'Completed' : 'Pending',
                      color: statusColor,
                    ),
                    const SizedBox(width: 16),
                    _StatusDot(
                      label: bill.paymentStatus.label,
                      color: AppColors.primary,
                    ),
                    const Spacer(),
                    if (onTap != null)
                      Icon(Icons.arrow_forward_rounded,
                          color: AppColors.textHint, size: 15),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny dot + label — replaces filled chip "noise".
class _StatusDot extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

enum _BillMenuAction { edit, delete }

// ── Shared Widgets ──

class _DateRangeChip extends StatelessWidget {
  final DateTimeRange? dateRange;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateRangeChip({
    required this.dateRange,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = dateRange != null;
    return Material(
      color: active ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: active ? null : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.date_range_outlined,
                size: 14,
                color: active ? AppColors.textOnPrimary : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                active
                    ? '${DateFormat('dd MMM').format(dateRange!.start)} – ${DateFormat('dd MMM').format(dateRange!.end)}'
                    : l10n.date,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      active ? AppColors.textOnPrimary : AppColors.textPrimary,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close_rounded,
                      size: 14,
                      color: AppColors.textOnPrimary.withValues(alpha: 0.8)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onTap;

  const _FilterIconButton({
    required this.hasActiveFilters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: hasActiveFilters
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasActiveFilters ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.tune_rounded,
                  size: 18,
                  color: hasActiveFilters
                      ? AppColors.primary
                      : AppColors.textPrimary),
              if (hasActiveFilters)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1),
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

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                size: 13, color: AppColors.primary.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: filled ? null : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: filled
                    ? AppColors.textOnPrimary
                    : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: filled
                      ? AppColors.textOnPrimary
                      : AppColors.textPrimary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

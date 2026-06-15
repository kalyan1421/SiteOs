import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/bill_model.dart';
import '../providers/bill_provider.dart';

/// Reusable bottom sheet for approving or rejecting a bill.
///
/// Shows bill context (type, vendor, description, receipt thumbnail),
/// lets admin choose payment status, mark completed, or reject with reason.
/// On success, calls [onSuccess] so the caller can refresh providers.
class BillApprovalSheet extends ConsumerStatefulWidget {
  final BillModel bill;
  final VoidCallback onSuccess;

  const BillApprovalSheet({
    super.key,
    required this.bill,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required BillModel bill,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BillApprovalSheet(bill: bill, onSuccess: onSuccess),
    );
  }

  @override
  ConsumerState<BillApprovalSheet> createState() => _BillApprovalSheetState();
}

class _BillApprovalSheetState extends ConsumerState<BillApprovalSheet> {
  late PaymentStatus _paymentStatus;
  bool _markCompleted = false;
  bool _isRejecting = false;
  bool _isSaving = false;
  final _rejectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _paymentStatus = widget.bill.paymentStatus;
    _markCompleted = widget.bill.status.isCompleted;
  }

  @override
  void dispose() {
    _rejectionController.dispose();
    super.dispose();
  }

  BillModel get bill => widget.bill;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final success = await ref
          .read(billControllerProvider.notifier)
          .updateBillApproval(
            billId: bill.id,
            paymentStatus: _paymentStatus,
            markCompleted: _markCompleted,
          );
      if (!mounted) return;
      if (success) {
        widget.onSuccess();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.billUpdatedSuccessfully)),
        );
      } else {
        final ctrlState = ref.read(billControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ctrlState.hasError
                  ? ctrlState.error.toString()
                  : 'Failed to update bill',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reject() async {
    final reason = _rejectionController.text.trim();
    if (reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a rejection reason (min 10 chars)'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final success = await ref
          .read(billControllerProvider.notifier)
          .rejectBill(bill.id, reason: reason);
      if (!mounted) return;
      if (success) {
        widget.onSuccess();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill rejected')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reject bill')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildBillContext(context),
            const Divider(height: 24),
            if (_isRejecting) ...[
              _buildRejectionField(),
              const SizedBox(height: 12),
              _buildRejectionActions(),
            ] else ...[
              _buildPaymentDropdown(),
              const SizedBox(height: 8),
              _buildCompletedSwitch(),
              const SizedBox(height: 16),
              _buildApproveActions(),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _isRejecting ? 'Reject Bill' : 'Review Bill',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _TypeBadge(type: bill.type),
      ],
    );
  }

  Widget _buildBillContext(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bill.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '₹${bill.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            if (bill.projectName != null) ...[
              const Icon(Icons.business_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                bill.projectName!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ],
        ),
        if (bill.vendorName != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.store_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                bill.vendorName!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ],
        if (bill.raisedByName != null || bill.createdByName != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'By: ${bill.raisedByName ?? bill.createdByName}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ],
        if (bill.description != null && bill.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            bill.description!,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (bill.receiptUrl != null && bill.receiptUrl!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ReceiptThumbnail(url: bill.receiptUrl!),
        ],
      ],
    );
  }

  Widget _buildPaymentDropdown() {
    return DropdownButtonFormField<PaymentStatus>(
      initialValue: _paymentStatus,
      decoration: const InputDecoration(
        labelText: 'Payment Decision',
        prefixIcon: Icon(Icons.payments_outlined),
      ),
      items: const [
        DropdownMenuItem(value: PaymentStatus.needToPay, child: Text('Pending')),
        DropdownMenuItem(value: PaymentStatus.advance, child: Text('Will Pay')),
        DropdownMenuItem(value: PaymentStatus.halfPaid, child: Text('Half Paid')),
        DropdownMenuItem(value: PaymentStatus.fullPaid, child: Text('Paid')),
      ],
      onChanged: _isSaving
          ? null
          : (v) {
              if (v != null) setState(() => _paymentStatus = v);
            },
    );
  }

  Widget _buildCompletedSwitch() {
    return SwitchListTile(
      value: _markCompleted,
      onChanged: _isSaving ? null : (v) => setState(() => _markCompleted = v),
      contentPadding: EdgeInsets.zero,
      title: const Text('Mark as Completed'),
      subtitle: const Text('Moves bill to Completed tab'),
    );
  }

  Widget _buildApproveActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : () => setState(() => _isRejecting = true),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Update'),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectionField() {
    return TextFormField(
      controller: _rejectionController,
      enabled: !_isSaving,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Rejection Reason *',
        hintText: 'Explain why this bill is being rejected (min 10 chars)',
        prefixIcon: Icon(Icons.comment_outlined),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildRejectionActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => setState(() => _isRejecting = false),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _reject,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm Reject'),
          ),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final BillType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ReceiptThumbnail extends StatelessWidget {
  final String url;
  const _ReceiptThumbnail({required this.url});

  bool get _isPdf => url.toLowerCase().contains('.pdf');

  @override
  Widget build(BuildContext context) {
    if (_isPdf) {
      return InkWell(
        onTap: () => _openReceipt(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'View Receipt (PDF)',
                  style: TextStyle(color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openReceipt(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: 60,
            color: AppColors.surface,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  void _openReceipt(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _isPdf
            ? _PdfReceiptViewer(url: url)
            : _ImageReceiptViewer(url: url),
      ),
    );
  }
}

class _PdfReceiptViewer extends StatelessWidget {
  final String url;
  const _PdfReceiptViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: 'Share',
            onPressed: () {
              // URL is public — user can copy from address bar in PDF viewer
            },
          ),
        ],
      ),
      body: SfPdfViewer.network(url),
    );
  }
}

class _ImageReceiptViewer extends StatelessWidget {
  final String url;
  const _ImageReceiptViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, _, _) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 48, color: Colors.white54),
                SizedBox(height: 8),
                Text('Failed to load image', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

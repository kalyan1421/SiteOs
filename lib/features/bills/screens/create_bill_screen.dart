import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/bill_model.dart';
import '../providers/bill_provider.dart';
import '../../projects/providers/project_provider.dart';
import '../../inventory/providers/inventory_provider.dart';

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form State
  String? _selectedProjectId;
  String? _title;
  String? _description;
  double? _amount;
  String? _vendorName;
  DateTime _billDate = DateTime.now();
  BillType _type = BillType.expense;
  PaymentType _paymentType = PaymentType.cash;
  PaymentStatus _paymentStatus = PaymentStatus.needToPay;
  List<int>? _receiptBytes;
  String? _receiptName;

  bool _isSubmitting = false;
  String? _selectedFileSize;

  @override
  void initState() {
    super.initState();
    // Load projects to select from
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectListProvider.notifier).loadProjects();
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pleaseSelectProject)));
      return;
    }

    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(billControllerProvider.notifier)
        .createBill(
          projectId: _selectedProjectId!,
          title: _title!,
          amount: _amount!,
          billType: _type.value,
          description: _description,
          vendorName: _vendorName,
          paymentType: _paymentType.value,
          paymentStatus: _paymentStatus.value,
          receiptBytes: _receiptBytes,
          receiptName: _receiptName,
          billDate: _billDate,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.billCreatedSuccessfully)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToCreateBill),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectState = ref.watch(projectListProvider);
    final createBillState = ref.watch(billControllerProvider);
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.billRequest)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Project Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: 'Project',
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: projectState.projects.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedProjectId = value),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Bill Type
                    DropdownButtonFormField<BillType>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: BillType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _type = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Title / Description',
                        hintText: 'e.g., Cement purchase',
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                      onSaved: (val) => _title = val,
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                      onSaved: (val) => _amount = double.parse(val!),
                    ),
                    const SizedBox(height: 16),

                    // Date Picker
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _billDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _billDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(_billDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vendor
                    suppliersAsync.when(
                      data: (suppliers) {
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Vendor Name (Optional)',
                            prefixIcon: Icon(Icons.store),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text(l10n.selectVendor),
                            ),
                            ...suppliers.map((supplier) {
                              return DropdownMenuItem<String>(
                                value: supplier.name,
                                child: Text(supplier.name),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(
                                () => _vendorName = val.isEmpty ? null : val,
                              );
                            }
                          },
                          onSaved: (val) =>
                              _vendorName =
                                  (val == null || val.isEmpty) ? null : val,
                        );
                      },
                      loading: () => InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Vendor Name (Optional)',
                          prefixIcon: Icon(Icons.store),
                        ),
                        child: const SizedBox(
                          height: 20,
                          child: LinearProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Vendor Name (Optional)',
                          prefixIcon: const Icon(Icons.store),
                          errorText: 'Could not load vendors',
                          errorStyle: TextStyle(
                            color: Colors.orange.shade700,
                          ),
                        ),
                        child: Text(
                          'Tap to retry',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<PaymentStatus>(
                      initialValue: _paymentStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.pending_actions_outlined),
                      ),
                      items: PaymentStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _paymentStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<PaymentType>(
                      initialValue: _paymentType,
                      decoration: const InputDecoration(
                        labelText: 'Payment Type',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: PaymentType.values.map((paymentType) {
                        return DropdownMenuItem(
                          value: paymentType,
                          child: Text(paymentType.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _paymentType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Receipt / Attachment
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
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
                                    setState(() {
                                      _receiptBytes = bytes;
                                      _receiptName = picked.name;
                                      _selectedFileSize = '${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB';
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
                                    setState(() {
                                      _receiptBytes = bytes;
                                      _receiptName = picked.name;
                                      _selectedFileSize = '${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB';
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
                                      final f = result.files.single;
                                      setState(() {
                                        _receiptBytes = f.bytes;
                                        _receiptName = f.name;
                                        _selectedFileSize = '${((f.bytes!.length) / (1024 * 1024)).toStringAsFixed(2)} MB';
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _receiptName != null ? AppColors.primary : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: _receiptName != null
                              ? AppColors.primary.withValues(alpha: 0.05)
                              : AppColors.surfaceVariant.withValues(alpha: 0.4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _receiptName != null ? Icons.check_circle_outline : Icons.attach_file_rounded,
                              size: 20,
                              color: _receiptName != null ? AppColors.primary : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _receiptName ?? 'Attach receipt (photo / PDF) — optional',
                                style: TextStyle(
                                  color: _receiptName != null ? AppColors.primary : AppColors.textHint,
                                  fontWeight: _receiptName != null ? FontWeight.w500 : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_receiptName != null) ...[
                              Text(
                                _selectedFileSize ?? '',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _receiptBytes = null;
                                  _receiptName = null;
                                  _selectedFileSize = null;
                                }),
                                child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: (_isSubmitting || createBillState.isLoading)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSubmitting || createBillState.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(l10n.addBill),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

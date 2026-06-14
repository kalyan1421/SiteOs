import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siteos/core/config/supabase_client.dart' show logger;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/master_data_provider.dart';
import '../providers/repository_providers.dart' show receiptsRepositoryProvider;
import '../providers/stock_provider.dart';
import '../data/models/material_grade_model.dart';
import '../../inventory/data/models/supplier_model.dart';
import '../../inventory/providers/inventory_provider.dart'
    show suppliersProvider, inventoryRepositoryProvider;
import '../data/models/material_master_model.dart';
import 'material_master_list_screen.dart' show allMaterialsProvider;

// Model to hold form state for each entry
class MaterialEntryForm {
  // Use unique key to force rebuild when removing/adding
  final Key key = UniqueKey();

  // Data holders
  MaterialMaster? selectedMaterial;
  MaterialGrade? selectedGrade;
  SupplierModel? selectedSupplier;

  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController billAmountController = TextEditingController();
  String paymentType = 'Cash'; // Default

  // Delivery receipt / invoice attachment
  List<int>? receiptBytes;
  String? receiptName;

  // Validation helper
  bool isValid() {
    final qty = double.tryParse(quantityController.text) ?? 0;
    // Bill amount can be 0 (e.g. sample?) but typically should be >= 0
    final amount = double.tryParse(billAmountController.text) ?? 0;

    return selectedMaterial != null &&
        selectedSupplier != null &&
        quantityController.text.isNotEmpty &&
        qty > 0 &&
        amount >= 0 &&
        unitController.text.isNotEmpty &&
        billAmountController.text.isNotEmpty;
  }

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
    billAmountController.dispose();
  }
}

class MaterialReceiveScreen extends ConsumerStatefulWidget {
  final String projectId;
  final bool isEmbedded;

  const MaterialReceiveScreen({
    super.key,
    required this.projectId,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<MaterialReceiveScreen> createState() =>
      _MaterialReceiveScreenState();
}

class _MaterialReceiveScreenState extends ConsumerState<MaterialReceiveScreen> {
  final List<MaterialEntryForm> _entries = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addNewEntry(); // Start with one entry
  }

  @override
  void dispose() {
    for (var entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addNewEntry() {
    setState(() {
      _entries.add(MaterialEntryForm());
    });
  }

  void _removeEntry(int index) {
    if (_entries.length > 1) {
      setState(() {
        _entries[index].dispose();
        _entries.removeAt(index);
      });
    }
  }

  Future<void> _submitAll() async {
    // 1) Validate entries first
    for (final entry in _entries) {
      if (!entry.isValid()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill all required fields in all entries'),
            ),
          );
        }
        return;
      }
    }

    // 2) Validate projectId BEFORE calling backend
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    final pid = widget.projectId.trim();

    if (!uuidRegex.hasMatch(pid) ||
        pid == '00000000-0000-0000-0000-000000000000') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid Project ID. Please open from Projects screen again.\n$pid',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stockRepo = ref.read(stockRepositoryProvider);
      final receiptsRepo = ref.read(receiptsRepositoryProvider);

      for (final entry in _entries) {
        // IMPORTANT: Send null grade if user didn't select
        final grade = (entry.selectedGrade?.gradeName.trim().isEmpty ?? true)
            ? null
            : entry.selectedGrade!.gradeName.trim();

        // Upload delivery receipt/invoice if provided
        String? receiptUrl;
        if (entry.receiptBytes != null && entry.receiptName != null) {
          try {
            final ext = entry.receiptName!.toLowerCase();
            final mimeType = ext.endsWith('.pdf')
                ? 'application/pdf'
                : ext.endsWith('.png')
                    ? 'image/png'
                    : 'image/jpeg';
            receiptUrl = await receiptsRepo.uploadAttachment(
              projectId: pid,
              fileName: entry.receiptName!,
              fileBytes: Uint8List.fromList(entry.receiptBytes!),
              mimeType: mimeType,
            );
          } catch (e) {
            logger.w('Receipt upload failed: $e');
            // Don't block submission; receipt is optional
          }
        }

        await stockRepo.logMaterialInward(
          projectId: pid,
          stockItemName: entry.selectedMaterial!.name,
          stockItemGrade: grade,
          stockItemUnit: entry.unitController.text.trim(),
          quantity: double.parse(entry.quantityController.text),
          supplierId: entry.selectedSupplier!.id,
          billAmount: double.parse(entry.billAmountController.text),
          paymentType: entry.paymentType,
          receiptUrl: receiptUrl,
          notes: null, // notes is not available in the form
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Materials received successfully')),
        );

        // Refresh the logs, stock, and material master providers
        ref.invalidate(materialLogsProvider(pid));
        ref.invalidate(stockBalanceProvider(pid));
        ref.invalidate(allMaterialsProvider);

        if (widget.isEmbedded) {
          Navigator.pop(context); // Close the bottom sheet
        } else {
          // Reset forms instead of popping if standing alone
          setState(() {
            for (var e in _entries) {
              e.dispose();
            }
            _entries.clear();
            _addNewEntry();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save material: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isEmbedded) ...[
                  const Text(
                    'Add data to the site ledger',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                ],

                // Dynamic Forms
                ..._entries.asMap().entries.map((item) {
                  final index = item.key;
                  final entry = item.value;
                  return _EntryCard(
                    key: entry.key,
                    entry: entry,
                    index: index,
                    projectId: widget.projectId,
                    onRemove: () => _removeEntry(index),
                    isRemovable: _entries.length > 1,
                  );
                }),

                const SizedBox(height: 16),

                // Action Buttons
                AppButton(
                  text: 'Save Material Entry',
                  onPressed: _submitAll,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _addNewEntry,
                    child: const Text(
                      'Add New Material',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );

    if (widget.isEmbedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Materials Received',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(child: bodyContent),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Log Materials'), centerTitle: false),
      body: bodyContent,
    );
  }
}

class _EntryCard extends ConsumerStatefulWidget {
  final MaterialEntryForm entry;
  final int index;
  final String projectId;
  final VoidCallback onRemove;
  final bool isRemovable;

  const _EntryCard({
    super.key,
    required this.entry,
    required this.index,
    required this.projectId,
    required this.onRemove,
    required this.isRemovable,
  });

  @override
  ConsumerState<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<_EntryCard> {
  // Grades are per-material; materials are shared via allMaterialsProvider
  List<MaterialGrade> _availableGrades = [];

  final List<String> _unitItems = const [
    'Bags',
    'CFT',
    'Cum',
    'Kg',
    'Liters',
    'Ton',
    'Units',
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchGrades(String materialName) async {
    try {
      final grades = await ref
          .read(materialMasterRepositoryProvider)
          .getGradesForMaterialName(materialName);
      if (mounted) setState(() => _availableGrades = grades);
    } catch (e) {
      logger.d('Error fetching grades: $e');
      if (mounted) setState(() => _availableGrades = []);
    }
  }

  Future<SupplierModel?> _openAddSupplierSheet(
    BuildContext context, {
    String initialName = '',
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    return showModalBottomSheet<SupplierModel?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add Vendor',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          prefixIcon: Icon(Icons.store),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contactCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contact Person',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: categoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.note_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setState(() => saving = true);
                                try {
                                  final repo = ref.read(
                                    inventoryRepositoryProvider,
                                  );
                                  final supplier = await repo.addSupplier(
                                    SupplierModel(
                                      id: '',
                                      name: nameCtrl.text.trim(),
                                      phone: phoneCtrl.text.trim().isEmpty
                                          ? null
                                          : phoneCtrl.text.trim(),
                                      email: emailCtrl.text.trim().isEmpty
                                          ? null
                                          : emailCtrl.text.trim(),
                                      contactPerson:
                                          contactCtrl.text.trim().isEmpty
                                          ? null
                                          : contactCtrl.text.trim(),
                                      address: addressCtrl.text.trim().isEmpty
                                          ? null
                                          : addressCtrl.text.trim(),
                                      category: categoryCtrl.text.trim().isEmpty
                                          ? null
                                          : categoryCtrl.text.trim(),
                                      notes: notesCtrl.text.trim().isEmpty
                                          ? null
                                          : notesCtrl.text.trim(),
                                      isActive: true,
                                      createdAt: null,
                                    ),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx, supplier);
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to add vendor: $e'),
                                      ),
                                    );
                                  }
                                } finally {
                                  setState(() => saving = false);
                                }
                              },
                        child: Text(saving ? 'Saving...' : 'Save'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    // Use the shared provider so all entry cards reuse one fetch, not N.
    final materialsAsync = ref.watch(allMaterialsProvider);
    final masterMaterials = materialsAsync.valueOrNull ?? <MaterialMaster>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isRemovable)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),

            // 1. MATERIAL DROPDOWN
            DropdownButtonFormField<MaterialMaster>(
              isExpanded: true,
              initialValue: entry.selectedMaterial,
              decoration: const InputDecoration(
                labelText: 'Material Name',
                hintText: '-- Select Material from Master List --',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              items: masterMaterials.map((item) {
                return DropdownMenuItem<MaterialMaster>(
                  value: item,
                  child: Text(item.name),
                );
              }).toList(),
              onChanged: (item) {
                setState(() {
                  entry.selectedMaterial = item;
                  entry.selectedGrade = null; // Reset grade
                  if (entry.unitController.text.isEmpty) {
                    entry.unitController.text = 'Units';
                  }
                  _availableGrades = []; // Clear old grades
                });
                if (item != null) {
                  _fetchGrades(item.name);
                }
              },
              validator: (val) => val == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // 2. GRADE DROPDOWN
            DropdownButtonFormField<MaterialGrade>(
              isExpanded: true,
              initialValue: entry.selectedGrade,
              decoration: const InputDecoration(
                labelText: 'Grade / Type',
                hintText: 'Select predefined grade',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              items: _availableGrades.map((g) {
                return DropdownMenuItem<MaterialGrade>(
                  value: g,
                  child: Text(g.gradeName),
                );
              }).toList(),
              onChanged: (g) {
                setState(() => entry.selectedGrade = g);
              },
              // Grade is optional when the material has no grades defined —
              // requiring it would permanently block submission.
              validator: (val) =>
                  val == null && _availableGrades.isNotEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: entry.quantityController,
                    label: 'Quantity',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _unitItems.contains(entry.unitController.text)
                        ? entry.unitController.text
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    items: _unitItems
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => entry.unitController.text = val);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. VENDOR DROPDOWN (filtered by selected material category)
            ref
                .watch(suppliersProvider)
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error loading suppliers: $e'),
                  data: (suppliers) {
                    // Filter suppliers by the selected material name/category.
                    // Only show suppliers whose category matches the selected
                    // material (or all suppliers when no material is chosen).
                    // Fallback: if no categorized supplier matches, show all so
                    // the form remains usable with uncategorized data.
                    final materialName = entry.selectedMaterial?.name.toLowerCase();
                    List<SupplierModel> filtered;
                    if (materialName == null) {
                      filtered = suppliers;
                    } else {
                      // Strict match: category matches the material
                      final strictMatch = suppliers.where((s) {
                        if (s.category == null) return false;
                        return s.category!.toLowerCase().contains(materialName) ||
                            materialName.contains(s.category!.toLowerCase());
                      }).toList();
                      // Fallback to all if no categorical match found
                      filtered = strictMatch.isNotEmpty ? strictMatch : suppliers;
                    }

                    // Reset selection if current supplier is no longer in list.
                    if (entry.selectedSupplier != null &&
                        !filtered.contains(entry.selectedSupplier)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => entry.selectedSupplier = null);
                      });
                    }

                    return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<SupplierModel>(
                          isExpanded: true,
                          initialValue: filtered.contains(entry.selectedSupplier)
                              ? entry.selectedSupplier
                              : null,
                          decoration: InputDecoration(
                            labelText: materialName != null
                                ? 'Vendor / Supplier (${entry.selectedMaterial!.name})'
                                : 'Vendor / Supplier',
                            hintText: 'Select vendor',
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                          ),
                          items: filtered.map((s) {
                            return DropdownMenuItem<SupplierModel>(
                              value: s,
                              child: Text(s.name),
                            );
                          }).toList(),
                          onChanged: (s) =>
                              setState(() => entry.selectedSupplier = s),
                          validator: (val) => val == null ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          final newSupplier = await _openAddSupplierSheet(
                            context,
                          );
                          if (newSupplier != null) {
                            ref.invalidate(suppliersProvider);
                            setState(
                              () => entry.selectedSupplier = newSupplier,
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        tooltip: 'Add New Vendor',
                      ),
                    ],
                    );
                  },
                ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: entry.paymentType,
              decoration: const InputDecoration(
                labelText: 'Payment Type',
                hintText: '-- Select Payment Type --',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              items: [
                'Cash',
                'Online',
                'Cheque',
                'Credit',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => entry.paymentType = val);
              },
            ),

            const SizedBox(height: 16),

            CurrencyTextField(
              controller: entry.billAmountController,
              label: 'Bill amount',
              // prefixText is handled internally by CurrencyTextField with prefixIcon
            ),

            const SizedBox(height: 16),

            // Delivery receipt / invoice photo (optional)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                          title: const Text('Take Photo'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            setState(() {
                              entry.receiptBytes = bytes;
                              entry.receiptName = picked.name;
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                          title: const Text('Choose from Gallery'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            setState(() {
                              entry.receiptBytes = bytes;
                              entry.receiptName = picked.name;
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.attach_file_outlined, color: AppColors.primary),
                          title: const Text('Browse Files (PDF / Image)'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                              withData: true,
                            );
                            if (result != null && result.files.single.bytes != null) {
                              setState(() {
                                entry.receiptBytes = result.files.single.bytes;
                                entry.receiptName = result.files.single.name;
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
                    color: entry.receiptName != null
                        ? AppColors.primary
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: entry.receiptName != null
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.receiptName != null
                          ? Icons.check_circle_outline
                          : Icons.receipt_long_outlined,
                      size: 20,
                      color: entry.receiptName != null
                          ? AppColors.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: entry.receiptName != null
                          ? Text(
                              entry.receiptName!,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              'Attach delivery receipt / invoice (optional)',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                    ),
                    if (entry.receiptName != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          entry.receiptBytes = null;
                          entry.receiptName = null;
                        }),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

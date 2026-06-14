import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/error_widget.dart';
import '../providers/stock_provider.dart';


// Provider imported from stock_provider.dart

class MaterialConsumeScreen extends ConsumerStatefulWidget {
  final String projectId;
  final bool isEmbedded;

  const MaterialConsumeScreen({
    super.key,
    required this.projectId,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<MaterialConsumeScreen> createState() =>
      _MaterialConsumeScreenState();
}

class _MaterialConsumeScreenState extends ConsumerState<MaterialConsumeScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedStockItemId;
  Map<String, dynamic>? _currentStockItem;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Attachment state
  Uint8List? _attachmentBytes;
  String? _attachmentName;
  String? _attachmentMime;

  bool _isLoading = false;

  Future<void> _pickAttachment(String source) async {
    try {
      if (source == 'camera') {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        setState(() {
          _attachmentBytes = bytes;
          _attachmentName = picked.name;
          _attachmentMime = 'image/jpeg';
        });
      } else if (source == 'gallery') {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last.toLowerCase();
        setState(() {
          _attachmentBytes = bytes;
          _attachmentName = picked.name;
          _attachmentMime = ext == 'png' ? 'image/png' : 'image/jpeg';
        });
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.single;
        if (file.bytes == null) return;
        final ext = file.extension?.toLowerCase() ?? 'pdf';
        setState(() {
          _attachmentBytes = file.bytes!;
          _attachmentName = file.name;
          _attachmentMime = ext == 'pdf'
              ? 'application/pdf'
              : ext == 'png'
                  ? 'image/png'
                  : 'image/jpeg';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick file: $e')),
        );
      }
    }
  }

  Future<void> _showAttachmentPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment('camera');
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment('gallery');
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_outlined, color: AppColors.primary),
              title: const Text('Browse Files (PDF/Image)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment('file');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadAttachment() async {
    if (_attachmentBytes == null || _attachmentName == null) return null;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitized = _attachmentName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '${widget.projectId}/consume/${timestamp}_$sanitized';
    await Supabase.instance.client.storage
        .from(AppConstants.bucketReceipts)
        .uploadBinary(
          path,
          _attachmentBytes!,
          fileOptions: FileOptions(contentType: _attachmentMime),
        );
    return Supabase.instance.client.storage
        .from(AppConstants.bucketReceipts)
        .getPublicUrl(path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStockItemId == null || _currentStockItem == null) return;

    final currentStock = (_currentStockItem!['current_stock'] as num).toDouble();
    final consumeQty = double.parse(_quantityController.text);

    if (consumeQty > currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: Only $currentStock ${_currentStockItem!['unit']} available',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? challanUrl;
      if (_attachmentBytes != null) {
        challanUrl = await _uploadAttachment();
      }

      await ref
          .read(stockRepositoryProvider)
          .logMaterialOutward(
            projectId: widget.projectId,
            itemId: _selectedStockItemId!,
            quantity: consumeQty,
            activity: _activityController.text.isNotEmpty
                ? _activityController.text
                : 'Material Consumed',
            notes: _notesController.text,
            challanUrl: challanUrl,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consumption logged successfully')),
        );
        ref.invalidate(materialLogsProvider(widget.projectId));
        ref.invalidate(stockBalanceProvider(widget.projectId));

        if (widget.isEmbedded) {
          Navigator.pop(context);
        } else {
          setState(() {
            _selectedStockItemId = null;
            _currentStockItem = null;
            _quantityController.clear();
            _activityController.clear();
            _notesController.clear();
            _attachmentBytes = null;
            _attachmentName = null;
            _attachmentMime = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockBalanceProvider(widget.projectId));

    final bodyContent = stockAsync.when(
      data: (stockItems) {
        // Filter out items with 0 stock
        final availableItems = stockItems
            .where((i) => (i['current_stock'] as num) > 0)
            .toList();

        if (availableItems.isEmpty) {
          return const EmptyStateWidget(
            message: 'No materials with available stock',
            icon: Icons.inventory_2_outlined,
          );
        }

        // Resolve the selected item object from the ID
        _currentStockItem = null;
        if (_selectedStockItemId != null) {
          try {
            _currentStockItem = availableItems.firstWhere(
              (item) => item['item_id'] == _selectedStockItemId,
            );
          } catch (e) {
            // Item might have disappeared or has 0 stock now
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _currentStockItem != null
                      ? _selectedStockItemId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Select Material',
                    border: OutlineInputBorder(),
                  ),
                  items: availableItems.map((item) {
                    return DropdownMenuItem(
                      value: item['item_id'] as String,
                      child: Text(
                        '${item['name']} ${item['grade'] ?? ''} (${item['current_stock']} ${item['unit']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedStockItemId = val;
                      // Reset quantity if changed
                      _quantityController.clear();
                    });
                  },
                  validator: (val) =>
                      val == null ? 'Please select a material' : null,
                ),
                const SizedBox(height: 16),

                if (_currentStockItem != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Available: ${_currentStockItem!['current_stock']} ${_currentStockItem!['unit']}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  CustomTextField(
                    controller: _quantityController,
                    label: 'Quantity Consumed',
                    hintText: '0.0',
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid number';
                      if (double.parse(val) <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _activityController,
                    label: 'Activity / Purpose',
                    hintText: 'e.g. Foundation Work',
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _notesController,
                    label: 'Notes (Optional)',
                    hintText: 'Any remarks...',
                  ),
                  const SizedBox(height: 16),

                  // Challan / proof of consumption attachment
                  if (_attachmentBytes == null)
                    OutlinedButton.icon(
                      onPressed: _showAttachmentPicker,
                      icon: const Icon(Icons.attach_file_outlined),
                      label: const Text('Attach Challan / Photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _attachmentMime == 'application/pdf'
                                ? Icons.picture_as_pdf
                                : Icons.image_outlined,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _attachmentName ?? 'Attachment',
                              style: const TextStyle(color: AppColors.success),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                            onPressed: () => setState(() {
                              _attachmentBytes = null;
                              _attachmentName = null;
                              _attachmentMime = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Log Consumption',
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => AppErrorWidget(
        message: 'Failed to load materials. Please try again.',
        onRetry: () =>
            ref.invalidate(stockBalanceProvider(widget.projectId)),
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
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_rounded, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Consume Material',
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
      appBar: AppBar(title: const Text('Log Consumption')),
      body: bodyContent,
    );
  }
}

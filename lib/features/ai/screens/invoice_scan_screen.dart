import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/invoice_ocr_result.dart';
import '../providers/ai_providers.dart';
import '../widgets/ai_widgets.dart';

/// AKS-75 — Pick a vendor invoice image, run Gemini Vision OCR, show fields.
class InvoiceScanScreen extends ConsumerStatefulWidget {
  const InvoiceScanScreen({super.key});

  @override
  ConsumerState<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

class _InvoiceScanScreenState extends ConsumerState<InvoiceScanScreen> {
  Uint8List? _imageBytes;
  String _mimeType = 'image/jpeg';
  bool _scanning = false;
  String? _error;
  InvoiceOcrResult? _result;

  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = res?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    final ext = (file.extension ?? 'jpg').toLowerCase();
    setState(() {
      _imageBytes = file.bytes;
      _mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      _result = null;
      _error = null;
    });
  }

  Future<void> _scan() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final base64 = base64Encode(bytes);
      final result = await ref.read(aiRepositoryProvider).scanInvoice(
            imageBase64: base64,
            mimeType: _mimeType,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _scanning = false;
      });
    }
  }

  String _money(double? v) => v == null ? '—' : _currency.format(v);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanInvoice)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            children: [
              const AiDisclaimerBanner(
                text: 'AI reads the invoice. Always double-check amounts '
                    'and GSTIN before saving.',
              ),
              const SizedBox(height: AppSpacing.s4),
              _ImagePreview(bytes: _imageBytes, onPick: _pickImage),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanning ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_imageBytes == null
                          ? 'Choose image'
                          : 'Change image'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          (_imageBytes == null || _scanning) ? null : _scan,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(l10n.scan),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s6),
                AiErrorState(message: _error!, onRetry: _scan),
              ],
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.s6),
                _ResultCard(result: _result!, money: _money),
              ],
            ],
          ),
          if (_scanning)
            const Positioned.fill(
              child: AiBusyOverlay(label: 'Reading invoice…'),
            ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onPick;

  const _ImagePreview({required this.bytes, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      size: 44, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.s2),
                  Text(l10n.tapToSelectInvoicePhoto,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textHint)),
                ],
              )
            : Image.memory(bytes!, fit: BoxFit.contain),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final InvoiceOcrResult result;
  final String Function(double?) money;

  const _ResultCard({required this.result, required this.money});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
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
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: AppSpacing.s2),
              Text(l10n.parsedInvoice, style: AppTextStyles.titleMedium),
            ],
          ),
          const Divider(height: AppSpacing.s6),
          AiFieldTile(label: 'Vendor', value: result.vendor ?? '—'),
          AiFieldTile(label: 'GSTIN', value: result.gstin ?? '—', mono: true),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AiFieldTile(
                    label: 'Invoice No',
                    value: result.invoiceNo ?? '—',
                    mono: true),
              ),
              Expanded(
                child: AiFieldTile(
                    label: 'Date', value: result.invoiceDate ?? '—'),
              ),
            ],
          ),
          if (result.lineItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(l10n.lineItems, style: AppTextStyles.labelSmall),
            const SizedBox(height: AppSpacing.s2),
            ...result.lineItems.map((li) => _LineItemRow(li: li, money: money)),
          ],
          const Divider(height: AppSpacing.s6),
          _TotalRow(label: 'Tax', value: money(result.taxAmount)),
          const SizedBox(height: AppSpacing.s1),
          _TotalRow(label: 'Total', value: money(result.total), bold: true),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: _asText(result, money)));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.copiedToClipboard)),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(l10n.copyDetails),
            ),
          ),
        ],
      ),
    );
  }

  String _asText(InvoiceOcrResult r, String Function(double?) money) {
    final b = StringBuffer()
      ..writeln('Vendor: ${r.vendor ?? '-'}')
      ..writeln('GSTIN: ${r.gstin ?? '-'}')
      ..writeln('Invoice No: ${r.invoiceNo ?? '-'}')
      ..writeln('Date: ${r.invoiceDate ?? '-'}')
      ..writeln('Tax: ${money(r.taxAmount)}')
      ..writeln('Total: ${money(r.total)}');
    return b.toString();
  }
}

class _LineItemRow extends StatelessWidget {
  final InvoiceLineItem li;
  final String Function(double?) money;

  const _LineItemRow({required this.li, required this.money});

  @override
  Widget build(BuildContext context) {
    final qty = li.quantity == null
        ? ''
        : '${li.quantity!.toStringAsFixed(li.quantity! % 1 == 0 ? 0 : 2)}'
            '${li.unit != null ? ' ${li.unit}' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(li.description, style: AppTextStyles.bodyMedium),
                if (qty.isNotEmpty)
                  Text(qty,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Text(money(li.amount),
              style: AppTextStyles.bodyMedium.copyWith(
                fontFamily: AppTextStyles.monoFontFamily,
              )),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _TotalRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: bold ? AppTextStyles.titleMedium : AppTextStyles.bodyMedium),
        Text(
          value,
          style: (bold ? AppTextStyles.titleMedium : AppTextStyles.bodyMedium)
              .copyWith(fontFamily: AppTextStyles.monoFontFamily),
        ),
      ],
    );
  }
}

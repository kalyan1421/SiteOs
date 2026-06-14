import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/boq_category_group.dart';
import '../models/boq_header_model.dart';
import '../models/boq_item_model.dart';

/// Builds and shares the BOQ "Abstract Sheet" PDF — a category-grouped bill of
/// quantities with per-line amounts, category subtotals, and a grand total.
class BoqPdfService {
  BoqPdfService();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  static String _money(num v) => _inr.format(v);
  static String _qty(num v) {
    final s = v.toStringAsFixed(3);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }

  /// Generates the PDF bytes for the given BOQ.
  Future<Uint8List> buildAbstractSheet({
    required BoqHeaderModel header,
    required List<BoqItemModel> items,
    String? projectName,
    String? companyName,
  }) async {
    final groups = groupBoqItemsByCategory(items);
    final grandTotal = boqGrandTotal(items);
    final doc = pw.Document();

    final mono = await PdfGoogleFonts.jetBrainsMonoRegular();
    final monoBold = await PdfGoogleFonts.jetBrainsMonoBold();
    final base = await PdfGoogleFonts.interRegular();
    final baseBold = await PdfGoogleFonts.interBold();

    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: base, bold: baseBold),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('${header.name} — ${header.version}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          // Title block
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (companyName != null && companyName.isNotEmpty)
                pw.Text(companyName,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text('BILL OF QUANTITIES — ABSTRACT SHEET',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (projectName != null && projectName.isNotEmpty)
                          pw.Text('Project: $projectName',
                              style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('BOQ: ${header.name}  (${header.version})',
                            style: const pw.TextStyle(fontSize: 10)),
                        if (header.notes != null &&
                            header.notes!.trim().isNotEmpty)
                          pw.Text('Notes: ${header.notes}',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.Text('Date: $dateStr',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
            ],
          ),
          pw.SizedBox(height: 8),

          // Per-category tables
          for (final group in groups) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(group.category.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ),
            _itemsTable(group, mono, monoBold),
            pw.SizedBox(height: 10),
          ],

          pw.Divider(thickness: 1.2, color: PdfColors.grey600),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('GRAND TOTAL   ',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(_money(grandTotal),
                    style: pw.TextStyle(
                        font: monoBold,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _itemsTable(BoqCategoryGroup group, pw.Font mono, pw.Font monoBold) {
    final headerStyle = pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final cellStyle = const pw.TextStyle(fontSize: 9);
    final numStyle = pw.TextStyle(font: mono, fontSize: 9);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.6),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.4),
        5: const pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: [
            _cell('#', headerStyle),
            _cell('Description', headerStyle),
            _cell('Unit', headerStyle),
            _cell('Qty', headerStyle, align: pw.TextAlign.right),
            _cell('Rate', headerStyle, align: pw.TextAlign.right),
            _cell('Amount', headerStyle, align: pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < group.items.length; i++)
          pw.TableRow(
            children: [
              _cell('${i + 1}', cellStyle),
              _cell(group.items[i].description, cellStyle),
              _cell(group.items[i].unit, cellStyle),
              _cell(_qty(group.items[i].qty), numStyle,
                  align: pw.TextAlign.right),
              _cell(_money(group.items[i].rate), numStyle,
                  align: pw.TextAlign.right),
              _cell(_money(group.items[i].computedAmount), numStyle,
                  align: pw.TextAlign.right),
            ],
          ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('', cellStyle),
            _cell('Subtotal — ${group.category}',
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            _cell('', cellStyle),
            _cell('', cellStyle),
            _cell('', cellStyle),
            _cell(_money(group.subtotal),
                pw.TextStyle(font: monoBold, fontSize: 9),
                align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  pw.Widget _cell(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  /// Opens the OS print / share sheet for the generated abstract sheet.
  Future<void> shareAbstractSheet({
    required BoqHeaderModel header,
    required List<BoqItemModel> items,
    String? projectName,
    String? companyName,
  }) async {
    final bytes = await buildAbstractSheet(
      header: header,
      items: items,
      projectName: projectName,
      companyName: companyName,
    );
    final safeName = header.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'BOQ_${safeName}_${header.version}.pdf',
    );
  }
}

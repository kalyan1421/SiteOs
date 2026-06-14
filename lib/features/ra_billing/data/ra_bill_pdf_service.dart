import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models/gst_config.dart';
import 'models/ra_bill.dart';

/// Renders an RA bill as a GST tax-invoice PDF and shares / prints it.
class RaBillPdfService {
  const RaBillPdfService();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );
  static String _m(double v) => _inr.format(v);

  /// Build the PDF bytes for [bill].
  Future<Uint8List> build({required RaBill bill, GstConfig? config}) async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy').format(bill.billDate);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _header(config, bill, dateStr),
          pw.SizedBox(height: 16),
          _partyBlock(bill),
          pw.SizedBox(height: 16),
          _workTable(bill),
          pw.SizedBox(height: 12),
          _taxTable(bill),
          pw.SizedBox(height: 16),
          _bankBlock(config),
          pw.Spacer(),
          _footer(),
        ],
      ),
    );
    return doc.save();
  }

  /// Build + open the native share / print sheet.
  Future<void> shareOrPrint({required RaBill bill, GstConfig? config}) async {
    final bytes = await build(bill: bill, config: config);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'RA_Bill_${bill.number.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Build + show the print preview / layout dialog.
  Future<void> printPreview({required RaBill bill, GstConfig? config}) async {
    await Printing.layoutPdf(
      name: 'RA_Bill_${bill.number}.pdf',
      onLayout: (format) async => build(bill: bill, config: config),
    );
  }

  pw.Widget _header(GstConfig? config, RaBill bill, String dateStr) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              config?.legalName ?? 'Company Name',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if ((config?.address ?? '').isNotEmpty)
              pw.Text(config!.address!,
                  style: const pw.TextStyle(fontSize: 9)),
            if ((config?.gstin ?? '').isNotEmpty)
              pw.Text('GSTIN: ${config!.gstin}',
                  style: const pw.TextStyle(fontSize: 9)),
            if ((config?.pan ?? '').isNotEmpty)
              pw.Text('PAN: ${config!.pan}',
                  style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('TAX INVOICE',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('RA Bill: ${bill.number}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Date: $dateStr',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Status: ${bill.status.label}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _partyBlock(RaBill bill) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Bill To',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(bill.clientName ?? 'Client',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          if ((bill.contractName ?? '').isNotEmpty)
            pw.Text('Contract: ${bill.contractName}',
                style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _workTable(RaBill bill) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
      headers: ['Particulars', 'Amount'],
      data: [
        ['Cumulative work done', _m(bill.cumulativeWorkDone)],
        ['Less: Previous work done', _m(bill.previousWorkDone)],
        ['Value of this bill', _m(bill.thisBillValue)],
        ['Less: Retention', _m(bill.retention)],
        ['Less: Advance recovery', _m(bill.advanceRecovery)],
        ['Taxable value', _m(bill.taxableValue)],
      ],
    );
  }

  pw.Widget _taxTable(RaBill bill) {
    final rows = <List<String>>[];
    if (bill.cgst > 0) rows.add(['CGST', _m(bill.cgst)]);
    if (bill.sgst > 0) rows.add(['SGST', _m(bill.sgst)]);
    if (bill.igst > 0) rows.add(['IGST', _m(bill.igst)]);
    rows.add(['Invoice total', _m(bill.taxableValue + bill.totalGst)]);
    if (bill.tds > 0) rows.add(['Less: TDS', _m(bill.tds)]);
    rows.add(['Net payable', _m(bill.netPayable)]);

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
      headers: ['Tax / Net', 'Amount'],
      data: rows,
    );
  }

  pw.Widget _bankBlock(GstConfig? config) {
    if (config == null ||
        ((config.bankName ?? '').isEmpty &&
            (config.bankAccountNo ?? '').isEmpty)) {
      return pw.SizedBox();
    }
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Bank Details',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          if ((config.bankName ?? '').isNotEmpty)
            pw.Text('Bank: ${config.bankName}',
                style: const pw.TextStyle(fontSize: 9)),
          if ((config.bankAccountNo ?? '').isNotEmpty)
            pw.Text('A/C No: ${config.bankAccountNo}',
                style: const pw.TextStyle(fontSize: 9)),
          if ((config.bankIfsc ?? '').isNotEmpty)
            pw.Text('IFSC: ${config.bankIfsc}',
                style: const pw.TextStyle(fontSize: 9)),
          if ((config.bankBranch ?? '').isNotEmpty)
            pw.Text('Branch: ${config.bankBranch}',
                style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _footer() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Text('This is a computer-generated tax invoice.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 24),
        pw.Text('Authorised Signatory',
            style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }
}

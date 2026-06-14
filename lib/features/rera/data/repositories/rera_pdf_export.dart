import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/rera_report.dart';

/// Generates and presents a RERA-format quarterly progress report PDF.
///
/// Layout follows the typical RERA "Quarterly Update" disclosure: project
/// identification, the reporting period, physical progress, and a
/// project-finance (funds received / utilized / balance) block, plus a
/// work-done narrative and a declaration footer.
class ReraPdfExport {
  ReraPdfExport._();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  static String _money(double v) => _inr.format(v);

  /// Builds the PDF for [report] and opens the platform print/share sheet.
  static Future<void> exportQuarterlyReport(ReraReport report) async {
    final doc = pw.Document();
    final generatedOn =
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
        footer: (context) => _footer(context, generatedOn),
        build: (context) => [
          _title(report),
          pw.SizedBox(height: 18),
          _sectionHeading('1. Project Details'),
          _kvTable([
            ['Project Name', report.projectName ?? report.projectId],
            ['Reporting Period', report.periodLabel],
            ['Filing Status', report.status.label],
          ]),
          pw.SizedBox(height: 16),
          _sectionHeading('2. Physical Progress'),
          _kvTable([
            [
              'Cumulative Completion',
              '${report.completionPct.toStringAsFixed(2)} %',
            ],
          ]),
          pw.SizedBox(height: 8),
          _progressBar(report.completionPct),
          pw.SizedBox(height: 16),
          _sectionHeading('3. Project Fund Status'),
          _fundsTable(report),
          pw.SizedBox(height: 16),
          _sectionHeading('4. Work Done During the Quarter'),
          pw.SizedBox(height: 4),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              (report.workDescription == null ||
                      report.workDescription!.trim().isEmpty)
                  ? 'No work description recorded for this quarter.'
                  : report.workDescription!.trim(),
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
          ),
          pw.SizedBox(height: 24),
          _declaration(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name:
          'RERA_${_safe(report.projectName ?? report.projectId)}_${report.periodLabel.replaceAll(' ', '_')}.pdf',
    );
  }

  // ── Components ─────────────────────────────────────────────────────

  static pw.Widget _title(ReraReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RERA QUARTERLY PROGRESS REPORT',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF0F172A),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Quarterly update under the Real Estate (Regulation and Development) Act, 2016',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: PdfColor.fromInt(0xFF1B4FD8)),
      ],
    );
  }

  static pw.Widget _sectionHeading(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      color: PdfColor.fromInt(0xFFEFF3FE),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF1B4FD8),
        ),
      ),
    );
  }

  static pw.Widget _kvTable(List<List<String>> rows) {
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: rows
          .map(
            (r) => pw.TableRow(
              children: [
                _cell(r[0], bold: true, bg: PdfColors.grey100),
                _cell(r[1]),
              ],
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _fundsTable(ReraReport report) {
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('Particulars', bold: true),
            _cell('Amount', bold: true, align: pw.TextAlign.right),
          ],
        ),
        pw.TableRow(children: [
          _cell('Funds Received from Allottees (this period)'),
          _cell(_money(report.fundsReceived), align: pw.TextAlign.right),
        ]),
        pw.TableRow(children: [
          _cell('Funds Utilized on Construction (this period)'),
          _cell(_money(report.fundsUtilized), align: pw.TextAlign.right),
        ]),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cell('Balance', bold: true),
            _cell(_money(report.fundsBalance),
                bold: true, align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  static pw.Widget _progressBar(double pct) {
    final clamped = pct.clamp(0, 100).toDouble();
    // Two flex children fill the bar proportionally: filled vs remaining.
    final filled = (clamped * 1000).round();
    final remaining = 100000 - filled;
    return pw.ClipRRect(
      horizontalRadius: 7,
      verticalRadius: 7,
      child: pw.Container(
        height: 14,
        color: PdfColors.grey200,
        child: pw.Row(
          children: [
            if (filled > 0)
              pw.Expanded(
                flex: filled,
                child: pw.Container(
                  color: PdfColor.fromInt(0xFF1B4FD8),
                ),
              ),
            if (remaining > 0)
              pw.Expanded(
                flex: remaining,
                child: pw.SizedBox(),
              ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _declaration() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeading('Declaration'),
        pw.SizedBox(height: 6),
        pw.Text(
          'I/We hereby declare that the information furnished above is true and '
          'correct to the best of my/our knowledge and belief, and is in '
          'accordance with the provisions of the Real Estate (Regulation and '
          'Development) Act, 2016 and the rules and regulations made thereunder.',
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
        ),
        pw.SizedBox(height: 40),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 160, height: 0.5, color: PdfColors.grey600),
                pw.SizedBox(height: 4),
                pw.Text('Authorized Signatory',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 120, height: 0.5, color: PdfColors.grey600),
                pw.SizedBox(height: 4),
                pw.Text('Date & Seal',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context, String generatedOn) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by SiteOS on $generatedOn',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor? bg,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 7),
      alignment: align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_');
}

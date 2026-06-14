import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/snag.dart';

/// Builds and shares/prints a snag report PDF for a project.
class SnagReportService {
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  /// Renders the PDF bytes for [snags] under [projectName].
  static Future<void> generateAndShare({
    required String projectName,
    required List<Snag> snags,
  }) async {
    final doc = pw.Document();

    final openCount =
        snags.where((s) => s.status == SnagStatus.open).length;
    final inProgressCount =
        snags.where((s) => s.status == SnagStatus.inProgress).length;
    final resolvedCount = snags.where((s) => s.status.isResolved).length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _header(projectName),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          _summaryRow(
            total: snags.length,
            open: openCount,
            inProgress: inProgressCount,
            resolved: resolvedCount,
          ),
          pw.SizedBox(height: 16),
          if (snags.isEmpty)
            pw.Text('No snags recorded for this project.',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))
          else
            _snagsTable(snags),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'snag_report_${projectName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf',
    );
  }

  static pw.Widget _header(String projectName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SiteOS — Snag Report',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(_dateFmt.format(DateTime.now()),
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Project: $projectName',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      ],
    );
  }

  static pw.Widget _summaryRow({
    required int total,
    required int open,
    required int inProgress,
    required int resolved,
  }) {
    pw.Widget cell(String label, int value, PdfColor color) {
      return pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 2),
              pw.Text('$value',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        cell('Total', total, PdfColors.blue800),
        cell('Open', open, PdfColors.red700),
        cell('In Progress', inProgress, PdfColors.orange700),
        cell('Resolved', resolved, PdfColors.green700),
      ],
    );
  }

  static pw.Widget _snagsTable(List<Snag> snags) {
    final headers = ['#', 'Title', 'Location', 'Priority', 'Status', 'Raised'];

    final rows = <List<String>>[];
    for (var i = 0; i < snags.length; i++) {
      final s = snags[i];
      rows.add([
        '${i + 1}',
        s.title,
        s.location ?? '-',
        s.priority.label,
        s.status.label,
        s.createdAt != null ? DateFormat('dd MMM yyyy').format(s.createdAt!) : '-',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.4),
        5: const pw.FlexColumnWidth(1.6),
      },
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
    );
  }
}

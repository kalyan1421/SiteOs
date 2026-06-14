import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models/gst_config.dart';
import 'models/ra_bill.dart';
import 'tally_xml_exporter.dart';

/// Writes a Tally Data Exchange XML for an RA bill to a temp file and opens
/// the native share sheet so the user can save / send it to Tally.
class TallyExportService {
  final TallyXmlExporter _exporter;

  const TallyExportService([this._exporter = const TallyXmlExporter()]);

  /// Generate the XML string for [bill] (no IO — useful for preview / tests).
  String generateXml({required RaBill bill, GstConfig? config}) {
    return _exporter.buildXml(bill: bill, config: config);
  }

  /// Generate the Tally XML and open the share sheet with it as an attachment.
  Future<void> exportAndShare({
    required RaBill bill,
    GstConfig? config,
  }) async {
    final xml = _exporter.buildXml(bill: bill, config: config);
    final dir = await getTemporaryDirectory();
    final fileName = _exporter.suggestedFileName(bill);
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(xml);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/xml', name: fileName)],
      subject: 'Tally XML — ${bill.number}',
      text: 'Tally import XML for RA bill ${bill.number}.',
    );
  }
}

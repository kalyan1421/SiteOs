import 'package:xml/xml.dart';

import 'models/gst_config.dart';
import 'models/ra_bill.dart';

/// Produces Tally Data Exchange XML (TallyPrime / Tally.ERP 9 import format)
/// for a single RA bill. The output is a `Sales` voucher with ledger entries
/// for the party (debit), the sales ledger (credit), CGST/SGST or IGST, and a
/// TDS deduction line — the same structure Tally expects on import.
///
/// Pure data → string. No Flutter / file IO here so it stays unit-testable.
class TallyXmlExporter {
  const TallyXmlExporter();

  /// Build the Tally XML document for [bill]. [config] supplies the supplier's
  /// legal name (used as the company / requested-company name).
  String buildXml({
    required RaBill bill,
    GstConfig? config,
    String? companyName,
    String salesLedgerName = 'Sales - RA Bill',
    String cgstLedgerName = 'CGST',
    String sgstLedgerName = 'SGST',
    String igstLedgerName = 'IGST',
    String tdsLedgerName = 'TDS Receivable',
  }) {
    final company =
        companyName ?? config?.legalName ?? 'SiteOS Company';
    final party = (bill.clientName?.trim().isNotEmpty ?? false)
        ? bill.clientName!.trim()
        : 'Client';

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('ENVELOPE', nest: () {
      builder.element('HEADER', nest: () {
        builder.element('TALLYREQUEST', nest: 'Import Data');
      });
      builder.element('BODY', nest: () {
        builder.element('IMPORTDATA', nest: () {
          builder.element('REQUESTDESC', nest: () {
            builder.element('REPORTNAME', nest: 'Vouchers');
            builder.element('STATICVARIABLES', nest: () {
              builder.element('SVCURRENTCOMPANY', nest: company);
            });
          });
          builder.element('REQUESTDATA', nest: () {
            builder.element('TALLYMESSAGE', attributes: {
              'xmlns:UDF': 'TallyUDF',
            }, nest: () {
              _buildVoucher(
                builder,
                bill: bill,
                party: party,
                salesLedgerName: salesLedgerName,
                cgstLedgerName: cgstLedgerName,
                sgstLedgerName: sgstLedgerName,
                igstLedgerName: igstLedgerName,
                tdsLedgerName: tdsLedgerName,
              );
            });
          });
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  void _buildVoucher(
    XmlBuilder builder, {
    required RaBill bill,
    required String party,
    required String salesLedgerName,
    required String cgstLedgerName,
    required String sgstLedgerName,
    required String igstLedgerName,
    required String tdsLedgerName,
  }) {
    final dateStr = _tallyDate(bill.billDate);
    final invoiceTotal = bill.taxableValue + bill.totalGst;

    builder.element('VOUCHER', attributes: {
      'VCHTYPE': 'Sales',
      'ACTION': 'Create',
      'OBJVIEW': 'Invoice Voucher View',
    }, nest: () {
      builder.element('DATE', nest: dateStr);
      builder.element('EFFECTIVEDATE', nest: dateStr);
      builder.element('VOUCHERTYPENAME', nest: 'Sales');
      builder.element('VOUCHERNUMBER', nest: bill.number);
      builder.element('PARTYLEDGERNAME', nest: party);
      builder.element('PARTYNAME', nest: party);
      builder.element('BASICBUYERNAME', nest: party);
      builder.element('PERSISTEDVIEW', nest: 'Invoice Voucher View');
      if ((bill.notes?.trim().isNotEmpty ?? false)) {
        builder.element('NARRATION', nest: bill.notes!.trim());
      }

      // Party ledger — debit the full invoice total (positive amount).
      _ledgerEntry(
        builder,
        ledgerName: party,
        isDeemedPositive: true,
        amount: invoiceTotal,
      );

      // Sales ledger — credit the taxable value (negative amount).
      _ledgerEntry(
        builder,
        ledgerName: salesLedgerName,
        isDeemedPositive: false,
        amount: -bill.taxableValue,
      );

      // GST ledgers (credit).
      if (bill.cgst > 0) {
        _ledgerEntry(
          builder,
          ledgerName: cgstLedgerName,
          isDeemedPositive: false,
          amount: -bill.cgst,
        );
      }
      if (bill.sgst > 0) {
        _ledgerEntry(
          builder,
          ledgerName: sgstLedgerName,
          isDeemedPositive: false,
          amount: -bill.sgst,
        );
      }
      if (bill.igst > 0) {
        _ledgerEntry(
          builder,
          ledgerName: igstLedgerName,
          isDeemedPositive: false,
          amount: -bill.igst,
        );
      }

      // TDS deducted by the client — recorded as a receivable (debit-side
      // reduction of the party balance; shown as a positive deemed entry).
      if (bill.tds > 0) {
        _ledgerEntry(
          builder,
          ledgerName: tdsLedgerName,
          isDeemedPositive: true,
          amount: bill.tds,
        );
      }
    });
  }

  void _ledgerEntry(
    XmlBuilder builder, {
    required String ledgerName,
    required bool isDeemedPositive,
    required double amount,
  }) {
    builder.element('ALLLEDGERENTRIES.LIST', nest: () {
      builder.element('LEDGERNAME', nest: ledgerName);
      builder.element('ISDEEMEDPOSITIVE',
          nest: isDeemedPositive ? 'Yes' : 'No');
      builder.element('AMOUNT', nest: _money(amount));
    });
  }

  /// Tally expects amounts as plain decimal strings (2 dp), credits negative.
  String _money(double v) => v.toStringAsFixed(2);

  /// Tally date format is YYYYMMDD.
  String _tallyDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// Suggested filename for the exported XML.
  String suggestedFileName(RaBill bill) {
    final safe = bill.number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'RA_Bill_$safe.xml';
  }
}

/// Pure-Dart GST / RA-bill math. No Flutter / Supabase imports — fully unit
/// testable. Implements Indian GST rules for Running-Account (RA) bills:
///
/// - **Intra-state** (supplier state == place-of-supply state): GST splits
///   into CGST + SGST, each at half the configured rate.
/// - **Inter-state** (different states): a single IGST at the full rate.
///
/// Retention and advance recovery are deducted from this bill's gross value to
/// arrive at the taxable value. GST is charged on the taxable value. TDS is
/// deducted from the (taxable + GST) to arrive at net payable.
class GstBreakdown {
  /// Gross value of work certified in this bill (cumulative − previous).
  final double thisBillValue;

  /// Retention withheld this bill = thisBillValue * retentionPct / 100.
  final double retention;

  /// Advance recovered this bill = thisBillValue * advanceRecoveryPct / 100
  /// (never more than [advanceOutstanding]).
  final double advanceRecovery;

  /// Value GST is charged on = thisBillValue − retention − advanceRecovery.
  final double taxableValue;

  final double cgst;
  final double sgst;
  final double igst;

  /// TDS deducted = (taxableValue + totalGst) * tdsPct / 100.
  final double tds;

  /// Amount actually payable to the supplier.
  final double netPayable;

  final bool isIntraState;

  const GstBreakdown({
    required this.thisBillValue,
    required this.retention,
    required this.advanceRecovery,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.tds,
    required this.netPayable,
    required this.isIntraState,
  });

  double get totalGst => cgst + sgst + igst;

  /// Invoice grand total (taxable + GST) before TDS deduction.
  double get invoiceTotal => taxableValue + totalGst;
}

/// Stateless calculator for RA-bill GST math.
class GstCalculator {
  const GstCalculator();

  /// Rounds money to 2 decimal places (paise), avoiding float drift.
  static double round2(double value) => (value * 100).roundToDouble() / 100;

  /// Whether two state codes represent the same state (intra-state supply).
  /// Comparison is whitespace- and case-insensitive; blanks are treated as a
  /// match (defaults to intra-state CGST+SGST when state info is missing).
  static bool isIntraState(String? supplierStateCode, String? clientStateCode) {
    final a = (supplierStateCode ?? '').trim();
    final b = (clientStateCode ?? '').trim();
    if (a.isEmpty || b.isEmpty) return true;
    return a.toLowerCase() == b.toLowerCase();
  }

  /// The value certified in *this* bill from running cumulative totals.
  /// Clamped at zero so a corrected (lower) cumulative never goes negative.
  static double thisBillValue({
    required double cumulativeWorkDone,
    required double previousWorkDone,
  }) {
    final v = cumulativeWorkDone - previousWorkDone;
    return v < 0 ? 0 : round2(v);
  }

  /// Compute the full GST / retention / advance / TDS breakdown for an RA bill.
  ///
  /// - [gstRatePct] is the FULL rate (e.g. 18). When intra-state it is split
  ///   in half across CGST and SGST.
  /// - [retentionPct] / [advanceRecoveryPct] / [tdsPct] are percentages.
  /// - [advanceOutstanding] caps advance recovery so we never recover more
  ///   than what remains outstanding (pass a large number / contract advance
  ///   if you don't track running outstanding).
  GstBreakdown compute({
    required double thisBillValue,
    required double gstRatePct,
    double retentionPct = 0,
    double advanceRecoveryPct = 0,
    double advanceOutstanding = double.infinity,
    double tdsPct = 0,
    String? supplierStateCode,
    String? clientStateCode,
  }) {
    final gross = thisBillValue < 0 ? 0.0 : thisBillValue;

    final retention = round2(gross * retentionPct / 100);

    var advanceRecovery = round2(gross * advanceRecoveryPct / 100);
    if (advanceRecovery > advanceOutstanding) {
      advanceRecovery = round2(advanceOutstanding < 0 ? 0 : advanceOutstanding);
    }

    var taxable = round2(gross - retention - advanceRecovery);
    if (taxable < 0) taxable = 0;

    final intra = isIntraState(supplierStateCode, clientStateCode);

    double cgst = 0;
    double sgst = 0;
    double igst = 0;
    if (intra) {
      final half = gstRatePct / 2;
      cgst = round2(taxable * half / 100);
      sgst = round2(taxable * half / 100);
    } else {
      igst = round2(taxable * gstRatePct / 100);
    }

    final totalGst = round2(cgst + sgst + igst);
    final invoiceTotal = round2(taxable + totalGst);
    final tds = round2(invoiceTotal * tdsPct / 100);
    final netPayable = round2(invoiceTotal - tds);

    return GstBreakdown(
      thisBillValue: round2(gross),
      retention: retention,
      advanceRecovery: advanceRecovery,
      taxableValue: taxable,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      tds: tds,
      netPayable: netPayable,
      isIntraState: intra,
    );
  }
}

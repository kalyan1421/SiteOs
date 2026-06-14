/// One category row in the BOQ-vs-Actual comparison.
///
/// "Estimate" comes from summing [boq_items] for the BOQ, grouped by category.
/// "Actual" comes from aggregating outward `material_logs` (consumption) joined
/// to `stock_items.category` for the project. When the actual source has no
/// matching data the actual fields stay null and the UI shows a TODO note.
class BoqVsActualRow {
  final String category;

  /// Estimated total amount (₹) from the BOQ for this category.
  final double estimateAmount;

  /// Estimated total quantity from the BOQ for this category (mixed units —
  /// shown as an indicative roll-up only).
  final double estimateQty;

  /// Actual consumed quantity from material_logs (outward), or null if the
  /// actual source could not be resolved for this category.
  final double? actualQty;

  /// Actual consumed value (₹) = actualQty × stock unit_price, or null.
  final double? actualAmount;

  const BoqVsActualRow({
    required this.category,
    required this.estimateAmount,
    required this.estimateQty,
    this.actualQty,
    this.actualAmount,
  });

  /// True when no actual consumption could be matched for this category.
  bool get actualUnknown => actualQty == null && actualAmount == null;

  /// Amount variance (actual − estimate). Null when actual is unknown.
  double? get amountVariance =>
      actualAmount == null ? null : actualAmount! - estimateAmount;

  /// Variance as a fraction of the estimate (−1.0 … +∞). Null when unknown
  /// or when the estimate is zero.
  double? get amountVariancePct {
    if (actualAmount == null || estimateAmount == 0) return null;
    return (actualAmount! - estimateAmount) / estimateAmount;
  }

  /// True when actual spend exceeds the estimate.
  bool get isOverBudget =>
      amountVariance != null && amountVariance! > 0;
}

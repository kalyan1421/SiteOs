/// A single estimated BOQ line returned by the `ai-boq` Edge Function.
class BoqRow {
  final String category;
  final String description;
  final String unit;
  final double quantity;
  final double rate;
  final double amount;

  const BoqRow({
    required this.category,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.amount,
  });

  factory BoqRow.fromJson(Map<String, dynamic> json) {
    final qty = _toDouble(json['quantity']) ?? 0;
    final rate = _toDouble(json['rate']) ?? 0;
    final amount = _toDouble(json['amount']) ?? (qty * rate);
    return BoqRow(
      category: (json['category'] ?? 'General').toString(),
      description: (json['description'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      quantity: qty,
      rate: rate,
      amount: amount,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'description': description,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
        'amount': amount,
      };
}

/// The full BOQ estimate (rows + the model's stated assumptions).
class BoqResult {
  final List<BoqRow> rows;
  final List<String> assumptions;
  final String currency;

  const BoqResult({
    this.rows = const [],
    this.assumptions = const [],
    this.currency = 'INR',
  });

  double get grandTotal =>
      rows.fold<double>(0, (sum, r) => sum + r.amount);

  factory BoqResult.fromJson(Map<String, dynamic> json) => BoqResult(
        rows: (json['rows'] as List? ?? [])
            .whereType<Map>()
            .map((e) => BoqRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        assumptions: (json['assumptions'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        currency: (json['currency'] as String?) ?? 'INR',
      );
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '').trim());
}

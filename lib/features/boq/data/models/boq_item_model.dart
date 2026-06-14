/// BOQ line item — a single priced line in a BOQ, grouped by category.
///
/// Maps to the `boq_items` table (migration 055_boq.sql). The `amount` column
/// is GENERATED in Postgres (qty * rate); on the client we compute it the same
/// way via [computedAmount] so the UI stays consistent before a round-trip.
class BoqItemModel {
  final String id;
  final String companyId;
  final String boqId;
  final String category;
  final String description;
  final String unit;
  final double qty;
  final double rate;

  /// Server-computed (qty * rate). May be null before the row is persisted.
  final double? amount;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BoqItemModel({
    required this.id,
    required this.companyId,
    required this.boqId,
    this.category = 'General',
    required this.description,
    this.unit = 'nos',
    this.qty = 0,
    this.rate = 0,
    this.amount,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Always-available amount: prefers the persisted server value, else qty*rate.
  double get computedAmount => amount ?? (qty * rate);

  factory BoqItemModel.fromJson(Map<String, dynamic> json) {
    return BoqItemModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String? ?? '',
      boqId: json['boq_id'] as String? ?? '',
      category: (json['category'] as String?)?.trim().isNotEmpty == true
          ? json['category'] as String
          : 'General',
      description: json['description'] as String? ?? '',
      unit: json['unit'] as String? ?? 'nos',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  /// Payload for INSERT. `amount` is GENERATED — never send it.
  Map<String, dynamic> toInsertJson() {
    return {
      'company_id': companyId,
      'boq_id': boqId,
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'description': description.trim(),
      'unit': unit.trim().isEmpty ? 'nos' : unit.trim(),
      'qty': qty,
      'rate': rate,
      'sort_order': sortOrder,
    };
  }

  BoqItemModel copyWith({
    String? id,
    String? companyId,
    String? boqId,
    String? category,
    String? description,
    String? unit,
    double? qty,
    double? rate,
    double? amount,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BoqItemModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      boqId: boqId ?? this.boqId,
      category: category ?? this.category,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

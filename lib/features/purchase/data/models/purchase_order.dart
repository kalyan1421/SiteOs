/// SiteOS Purchase Order Workflow (AKS-83) — Purchase Order models.
///
/// Maps to the `purchase_orders` and `po_items` tables created in
/// migration 060_purchase_orders.sql.
library;

/// Status of a purchase order.
enum PoStatus {
  draft('draft', 'Draft'),
  approved('approved', 'Approved'),
  received('received', 'Received'),
  cancelled('cancelled', 'Cancelled');

  final String key;
  final String label;
  const PoStatus(this.key, this.label);

  static PoStatus fromKey(String? key) => PoStatus.values.firstWhere(
        (s) => s.key == key,
        orElse: () => PoStatus.draft,
      );
}

/// A single line item on a purchase order.
class PoItem {
  final String? id;
  final String? poId;
  final String material;
  final double qty;
  final String? unit;
  final double rate;
  final double amount;

  /// Received quantity recorded via the 3-way GRN match.
  final double receivedQty;

  const PoItem({
    this.id,
    this.poId,
    required this.material,
    required this.qty,
    this.unit,
    required this.rate,
    required this.amount,
    this.receivedQty = 0,
  });

  /// amount = qty * rate (computed convenience).
  static double computeAmount(double qty, double rate) => qty * rate;

  /// Whether the received qty matches the ordered qty (within tolerance).
  bool get isMatched => (receivedQty - qty).abs() < 0.001;

  /// Positive when short-received, negative when over-received.
  double get variance => qty - receivedQty;

  factory PoItem.fromJson(Map<String, dynamic> json) => PoItem(
        id: json['id'] as String?,
        poId: json['po_id'] as String?,
        material: json['material'] as String? ?? '',
        qty: _toDouble(json['qty']),
        unit: json['unit'] as String?,
        rate: _toDouble(json['rate']),
        amount: _toDouble(json['amount']),
        receivedQty: _toDouble(json['received_qty']),
      );

  /// Payload for insert (company_id + po_id supplied by the repository).
  Map<String, dynamic> toInsertJson() => {
        'material': material,
        'qty': qty,
        if (unit != null) 'unit': unit,
        'rate': rate,
        'amount': amount,
        'received_qty': receivedQty,
      };

  PoItem copyWith({
    String? id,
    String? poId,
    String? material,
    double? qty,
    String? unit,
    double? rate,
    double? amount,
    double? receivedQty,
  }) =>
      PoItem(
        id: id ?? this.id,
        poId: poId ?? this.poId,
        material: material ?? this.material,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        rate: rate ?? this.rate,
        amount: amount ?? this.amount,
        receivedQty: receivedQty ?? this.receivedQty,
      );
}

/// A purchase order raised from an indent against a supplier.
class PurchaseOrder {
  final String? id;
  final String? companyId;
  final String? indentId;
  final String? projectId;
  final String? supplierId;
  final String? poNo;
  final PoStatus status;
  final double total;
  final String? notes;
  final DateTime? expectedAt;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<PoItem> items;

  const PurchaseOrder({
    this.id,
    this.companyId,
    this.indentId,
    this.projectId,
    this.supplierId,
    this.poNo,
    this.status = PoStatus.draft,
    this.total = 0,
    this.notes,
    this.expectedAt,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  /// Sum of all line amounts.
  double get computedTotal =>
      items.fold<double>(0, (sum, i) => sum + i.amount);

  /// True when every line's received qty matches its ordered qty.
  bool get isFullyMatched =>
      items.isNotEmpty && items.every((i) => i.isMatched);

  /// Count of lines with a quantity mismatch.
  int get mismatchCount => items.where((i) => !i.isMatched).length;

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['po_items'] as List<dynamic>?;
    return PurchaseOrder(
      id: json['id'] as String?,
      companyId: json['company_id'] as String?,
      indentId: json['indent_id'] as String?,
      projectId: json['project_id'] as String?,
      supplierId: json['supplier_id'] as String?,
      poNo: json['po_no'] as String?,
      status: PoStatus.fromKey(json['status'] as String?),
      total: _toDouble(json['total']),
      notes: json['notes'] as String?,
      expectedAt: _toDate(json['expected_at']),
      createdBy: json['created_by'] as String?,
      createdAt: _toDateTime(json['created_at']),
      updatedAt: _toDateTime(json['updated_at']),
      items: rawItems == null
          ? const []
          : rawItems
              .map((e) => PoItem.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  /// Header payload for insert/update (company_id supplied by the repository).
  Map<String, dynamic> toJson() => {
        if (indentId != null) 'indent_id': indentId,
        if (projectId != null) 'project_id': projectId,
        if (supplierId != null) 'supplier_id': supplierId,
        if (poNo != null) 'po_no': poNo,
        'status': status.key,
        'total': total,
        if (notes != null) 'notes': notes,
        if (expectedAt != null)
          'expected_at': expectedAt!.toIso8601String().split('T').first,
        if (createdBy != null) 'created_by': createdBy,
      };

  PurchaseOrder copyWith({
    String? id,
    String? companyId,
    String? indentId,
    String? projectId,
    String? supplierId,
    String? poNo,
    PoStatus? status,
    double? total,
    String? notes,
    DateTime? expectedAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PoItem>? items,
  }) =>
      PurchaseOrder(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        indentId: indentId ?? this.indentId,
        projectId: projectId ?? this.projectId,
        supplierId: supplierId ?? this.supplierId,
        poNo: poNo ?? this.poNo,
        status: status ?? this.status,
        total: total ?? this.total,
        notes: notes ?? this.notes,
        expectedAt: expectedAt ?? this.expectedAt,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        items: items ?? this.items,
      );
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

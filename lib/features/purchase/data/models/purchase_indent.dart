/// SiteOS Purchase Order Workflow (AKS-83) — Purchase Indent models.
///
/// Maps to the `purchase_indents` and `indent_items` tables created in
/// migration 060_purchase_orders.sql.
library;

/// Status of a purchase indent.
enum IndentStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  closed('closed', 'Closed');

  final String key;
  final String label;
  const IndentStatus(this.key, this.label);

  static IndentStatus fromKey(String? key) => IndentStatus.values.firstWhere(
        (s) => s.key == key,
        orElse: () => IndentStatus.draft,
      );
}

/// A single line item on a purchase indent.
class IndentItem {
  final String? id;
  final String? indentId;
  final String material;
  final double qty;
  final String? unit;
  final String? notes;

  const IndentItem({
    this.id,
    this.indentId,
    required this.material,
    required this.qty,
    this.unit,
    this.notes,
  });

  factory IndentItem.fromJson(Map<String, dynamic> json) => IndentItem(
        id: json['id'] as String?,
        indentId: json['indent_id'] as String?,
        material: json['material'] as String? ?? '',
        qty: _toDouble(json['qty']),
        unit: json['unit'] as String?,
        notes: json['notes'] as String?,
      );

  /// Payload for insert (company_id + indent_id supplied by the repository).
  Map<String, dynamic> toInsertJson() => {
        'material': material,
        'qty': qty,
        if (unit != null) 'unit': unit,
        if (notes != null) 'notes': notes,
      };

  IndentItem copyWith({
    String? id,
    String? indentId,
    String? material,
    double? qty,
    String? unit,
    String? notes,
  }) =>
      IndentItem(
        id: id ?? this.id,
        indentId: indentId ?? this.indentId,
        material: material ?? this.material,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        notes: notes ?? this.notes,
      );
}

/// A purchase indent (material request raised against a project).
class PurchaseIndent {
  final String? id;
  final String? companyId;
  final String? projectId;
  final String? indentNo;
  final String? title;
  final String? requestedBy;
  final IndentStatus status;
  final String? notes;
  final DateTime? requiredBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<IndentItem> items;

  const PurchaseIndent({
    this.id,
    this.companyId,
    this.projectId,
    this.indentNo,
    this.title,
    this.requestedBy,
    this.status = IndentStatus.draft,
    this.notes,
    this.requiredBy,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory PurchaseIndent.fromJson(Map<String, dynamic> json) {
    final rawItems = json['indent_items'] as List<dynamic>?;
    return PurchaseIndent(
      id: json['id'] as String?,
      companyId: json['company_id'] as String?,
      projectId: json['project_id'] as String?,
      indentNo: json['indent_no'] as String?,
      title: json['title'] as String?,
      requestedBy: json['requested_by'] as String?,
      status: IndentStatus.fromKey(json['status'] as String?),
      notes: json['notes'] as String?,
      requiredBy: _toDate(json['required_by']),
      createdAt: _toDateTime(json['created_at']),
      updatedAt: _toDateTime(json['updated_at']),
      items: rawItems == null
          ? const []
          : rawItems
              .map((e) => IndentItem.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  /// Header payload for insert/update (company_id supplied by the repository).
  Map<String, dynamic> toJson() => {
        if (projectId != null) 'project_id': projectId,
        if (indentNo != null) 'indent_no': indentNo,
        if (title != null) 'title': title,
        if (requestedBy != null) 'requested_by': requestedBy,
        'status': status.key,
        if (notes != null) 'notes': notes,
        if (requiredBy != null)
          'required_by': requiredBy!.toIso8601String().split('T').first,
      };

  PurchaseIndent copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? indentNo,
    String? title,
    String? requestedBy,
    IndentStatus? status,
    String? notes,
    DateTime? requiredBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<IndentItem>? items,
  }) =>
      PurchaseIndent(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        projectId: projectId ?? this.projectId,
        indentNo: indentNo ?? this.indentNo,
        title: title ?? this.title,
        requestedBy: requestedBy ?? this.requestedBy,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        requiredBy: requiredBy ?? this.requiredBy,
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

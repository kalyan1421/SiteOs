/// Approval/payment status of a subcontractor RA bill.
enum SubRaBillStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  approved('approved', 'Approved'),
  paid('paid', 'Paid');

  final String value;
  final String label;
  const SubRaBillStatus(this.value, this.label);

  static SubRaBillStatus fromValue(String? value) =>
      SubRaBillStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => SubRaBillStatus.draft,
      );
}

/// A running-account bill raised against a work order. Carries TDS + retention
/// deductions; net is what's actually payable to the subcontractor.
///
/// Maps to the `sub_ra_bills` table (migration 062_subcontractor.sql).
///
/// Deduction math (mirrors the GST/RA billing style used elsewhere):
///   tds       = value * tdsPct / 100
///   retention = value * retentionPct / 100
///   net       = value - tds - retention
class SubRaBillModel {
  final String id;
  final String companyId;
  final String workOrderId;
  final String number;
  final double value;
  final double tdsPct;
  final double tds;
  final double retentionPct;
  final double retention;
  final double net;
  final DateTime? billDate;
  final SubRaBillStatus status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubRaBillModel({
    required this.id,
    required this.companyId,
    required this.workOrderId,
    required this.number,
    this.value = 0,
    this.tdsPct = 0,
    this.tds = 0,
    this.retentionPct = 0,
    this.retention = 0,
    this.net = 0,
    this.billDate,
    this.status = SubRaBillStatus.draft,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Pure deduction calculator — single source of truth shared by the form
  /// (live preview) and the repository (persisted values).
  static ({double tds, double retention, double net}) calc({
    required double value,
    required double tdsPct,
    required double retentionPct,
  }) {
    final tds = value * (tdsPct / 100);
    final retention = value * (retentionPct / 100);
    final net = value - tds - retention;
    return (tds: tds, retention: retention, net: net);
  }

  factory SubRaBillModel.fromJson(Map<String, dynamic> json) {
    return SubRaBillModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      workOrderId: json['work_order_id'] as String,
      number: json['number'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      tdsPct: (json['tds_pct'] as num?)?.toDouble() ?? 0,
      tds: (json['tds'] as num?)?.toDouble() ?? 0,
      retentionPct: (json['retention_pct'] as num?)?.toDouble() ?? 0,
      retention: (json['retention'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
      billDate: json['bill_date'] != null
          ? DateTime.tryParse(json['bill_date'].toString())
          : null,
      status: SubRaBillStatus.fromValue(json['status'] as String?),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  /// Payload for insert/update. Excludes server-managed columns.
  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'work_order_id': workOrderId,
      'number': number,
      'value': value,
      'tds_pct': tdsPct,
      'tds': tds,
      'retention_pct': retentionPct,
      'retention': retention,
      'net': net,
      'bill_date': billDate?.toIso8601String(),
      'status': status.value,
      'notes': notes,
    };
  }

  SubRaBillModel copyWith({
    String? id,
    String? companyId,
    String? workOrderId,
    String? number,
    double? value,
    double? tdsPct,
    double? tds,
    double? retentionPct,
    double? retention,
    double? net,
    DateTime? billDate,
    SubRaBillStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubRaBillModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      workOrderId: workOrderId ?? this.workOrderId,
      number: number ?? this.number,
      value: value ?? this.value,
      tdsPct: tdsPct ?? this.tdsPct,
      tds: tds ?? this.tds,
      retentionPct: retentionPct ?? this.retentionPct,
      retention: retention ?? this.retention,
      net: net ?? this.net,
      billDate: billDate ?? this.billDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SubRaBillModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

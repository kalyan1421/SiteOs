/// Lifecycle status of a work order.
enum WorkOrderStatus {
  active('active', 'Active'),
  onHold('on_hold', 'On Hold'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  final String value;
  final String label;
  const WorkOrderStatus(this.value, this.label);

  static WorkOrderStatus fromValue(String? value) =>
      WorkOrderStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => WorkOrderStatus.active,
      );
}

/// A scope of work awarded to a subcontractor, optionally tied to a project.
///
/// Maps to the `work_orders` table (migration 062_subcontractor.sql).
class WorkOrderModel {
  final String id;
  final String companyId;
  final String subcontractorId;
  final String? projectId;
  final String? woNumber;
  final String scope;
  final double value;
  final double retentionPct;
  final double tdsPct;
  final WorkOrderStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined display fields (read-only, populated by repository joins).
  final String? subcontractorName;
  final String? projectName;

  const WorkOrderModel({
    required this.id,
    required this.companyId,
    required this.subcontractorId,
    this.projectId,
    this.woNumber,
    required this.scope,
    this.value = 0,
    this.retentionPct = 0,
    this.tdsPct = 0,
    this.status = WorkOrderStatus.active,
    this.startDate,
    this.endDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.subcontractorName,
    this.projectName,
  });

  /// Amount held back as retention against the full WO value.
  double get retentionAmount => value * (retentionPct / 100);

  factory WorkOrderModel.fromJson(Map<String, dynamic> json) {
    final sub = json['subcontractors'];
    final proj = json['projects'];
    return WorkOrderModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      subcontractorId: json['subcontractor_id'] as String,
      projectId: json['project_id'] as String?,
      woNumber: json['wo_number'] as String?,
      scope: json['scope'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      retentionPct: (json['retention_pct'] as num?)?.toDouble() ?? 0,
      tdsPct: (json['tds_pct'] as num?)?.toDouble() ?? 0,
      status: WorkOrderStatus.fromValue(json['status'] as String?),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString())
          : null,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      subcontractorName: sub is Map ? sub['name'] as String? : null,
      projectName: proj is Map ? proj['name'] as String? : null,
    );
  }

  /// Payload for insert/update. Excludes server-managed + joined columns.
  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'subcontractor_id': subcontractorId,
      'project_id': projectId,
      'wo_number': woNumber,
      'scope': scope,
      'value': value,
      'retention_pct': retentionPct,
      'tds_pct': tdsPct,
      'status': status.value,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
    };
  }

  WorkOrderModel copyWith({
    String? id,
    String? companyId,
    String? subcontractorId,
    String? projectId,
    String? woNumber,
    String? scope,
    double? value,
    double? retentionPct,
    double? tdsPct,
    WorkOrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? subcontractorName,
    String? projectName,
  }) {
    return WorkOrderModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      subcontractorId: subcontractorId ?? this.subcontractorId,
      projectId: projectId ?? this.projectId,
      woNumber: woNumber ?? this.woNumber,
      scope: scope ?? this.scope,
      value: value ?? this.value,
      retentionPct: retentionPct ?? this.retentionPct,
      tdsPct: tdsPct ?? this.tdsPct,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subcontractorName: subcontractorName ?? this.subcontractorName,
      projectName: projectName ?? this.projectName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is WorkOrderModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

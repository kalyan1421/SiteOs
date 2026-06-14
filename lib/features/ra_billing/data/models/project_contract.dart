/// A contract between the company and a client, parameterising RA bills
/// (contract value, retention %, advance, GST/TDS rates).
/// Maps to the `project_contracts` table (migration 056_ra_billing.sql).
class ProjectContract {
  final String id;
  final String companyId;
  final String? projectId;
  final String? clientId;
  final String name;
  final double contractValue;
  final double retentionPct;
  final double advance;
  final double advanceRecoveryPct;
  final double gstRate;
  final double tdsPct;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined (read-only) fields populated from related rows when available.
  final String? clientName;
  final String? clientStateCode;

  const ProjectContract({
    required this.id,
    required this.companyId,
    this.projectId,
    this.clientId,
    required this.name,
    this.contractValue = 0,
    this.retentionPct = 0,
    this.advance = 0,
    this.advanceRecoveryPct = 0,
    this.gstRate = 18,
    this.tdsPct = 0,
    this.createdAt,
    this.updatedAt,
    this.clientName,
    this.clientStateCode,
  });

  factory ProjectContract.fromJson(Map<String, dynamic> json) {
    final client = json['clients'] as Map<String, dynamic>?;
    return ProjectContract(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String?,
      clientId: json['client_id'] as String?,
      name: json['name'] as String? ?? '',
      contractValue: (json['contract_value'] as num?)?.toDouble() ?? 0,
      retentionPct: (json['retention_pct'] as num?)?.toDouble() ?? 0,
      advance: (json['advance'] as num?)?.toDouble() ?? 0,
      advanceRecoveryPct:
          (json['advance_recovery_pct'] as num?)?.toDouble() ?? 0,
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 18,
      tdsPct: (json['tds_pct'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      clientName: client?['name'] as String?,
      clientStateCode: client?['state_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'client_id': clientId,
        'name': name,
        'contract_value': contractValue,
        'retention_pct': retentionPct,
        'advance': advance,
        'advance_recovery_pct': advanceRecoveryPct,
        'gst_rate': gstRate,
        'tds_pct': tdsPct,
      };

  ProjectContract copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? clientId,
    String? name,
    double? contractValue,
    double? retentionPct,
    double? advance,
    double? advanceRecoveryPct,
    double? gstRate,
    double? tdsPct,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? clientName,
    String? clientStateCode,
  }) =>
      ProjectContract(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        projectId: projectId ?? this.projectId,
        clientId: clientId ?? this.clientId,
        name: name ?? this.name,
        contractValue: contractValue ?? this.contractValue,
        retentionPct: retentionPct ?? this.retentionPct,
        advance: advance ?? this.advance,
        advanceRecoveryPct: advanceRecoveryPct ?? this.advanceRecoveryPct,
        gstRate: gstRate ?? this.gstRate,
        tdsPct: tdsPct ?? this.tdsPct,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        clientName: clientName ?? this.clientName,
        clientStateCode: clientStateCode ?? this.clientStateCode,
      );
}

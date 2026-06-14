/// BOQ header — a named, versioned estimate for one project.
///
/// Maps to the `boq_headers` table (migration 055_boq.sql).
class BoqHeaderModel {
  final String id;
  final String companyId;
  final String projectId;
  final String name;
  final String version;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Optional roll-up of all line `amount`s, when the caller joins items.
  /// Not a DB column — populated by the repository when available.
  final double? total;

  const BoqHeaderModel({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.name,
    this.version = 'v1',
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.total,
  });

  factory BoqHeaderModel.fromJson(Map<String, dynamic> json) {
    return BoqHeaderModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled BOQ',
      version: json['version'] as String? ?? 'v1',
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      total: (json['total'] as num?)?.toDouble(),
    );
  }

  /// Payload for INSERT/UPDATE. `company_id` and `project_id` are required for
  /// inserts; omit nulls so generated/defaulted columns are left untouched.
  Map<String, dynamic> toInsertJson() {
    return {
      'company_id': companyId,
      'project_id': projectId,
      'name': name,
      'version': version,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  BoqHeaderModel copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? name,
    String? version,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? total,
  }) {
    return BoqHeaderModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      version: version ?? this.version,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      total: total ?? this.total,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

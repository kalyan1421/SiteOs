import 'package:flutter/foundation.dart';

/// Filing status for a RERA quarterly report.
enum ReraReportStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  approved('approved', 'Approved');

  final String value;
  final String label;
  const ReraReportStatus(this.value, this.label);

  static ReraReportStatus fromValue(String? value) =>
      ReraReportStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => ReraReportStatus.draft,
      );
}

/// A single quarterly RERA progress filing for one project.
///
/// Backed by the `rera_reports` table (migration 061_rera.sql). One row per
/// project per quarter/year.
@immutable
class ReraReport {
  final String id;
  final String companyId;
  final String projectId;

  /// Quarter of the financial/calendar year, 1–4.
  final int quarter;

  /// Four digit year, e.g. 2026.
  final int year;

  /// Physical completion percentage, 0–100.
  final double completionPct;

  /// Free-text description of work done in the quarter.
  final String? workDescription;

  /// Funds received from allottees during the period (₹).
  final double fundsReceived;

  /// Funds utilized / spent on construction during the period (₹).
  final double fundsUtilized;

  final ReraReportStatus status;

  /// Optional joined project name (from the `projects` relation), when the
  /// repository selects it. Not persisted on this table.
  final String? projectName;

  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReraReport({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.quarter,
    required this.year,
    this.completionPct = 0,
    this.workDescription,
    this.fundsReceived = 0,
    this.fundsUtilized = 0,
    this.status = ReraReportStatus.draft,
    this.projectName,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Funds remaining (received minus utilized). May be negative if over-spent.
  double get fundsBalance => fundsReceived - fundsUtilized;

  /// `Q3 2026` style label.
  String get periodLabel => 'Q$quarter $year';

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  factory ReraReport.fromJson(Map<String, dynamic> json) {
    // The repository may select a nested `projects` relation for the name.
    String? projectName;
    final proj = json['projects'];
    if (proj is Map<String, dynamic>) {
      projectName = proj['name'] as String?;
    }
    return ReraReport(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      quarter: _toInt(json['quarter']),
      year: _toInt(json['year']),
      completionPct: _toDouble(json['completion_pct']),
      workDescription: json['work_description'] as String?,
      fundsReceived: _toDouble(json['funds_received']),
      fundsUtilized: _toDouble(json['funds_utilized']),
      status: ReraReportStatus.fromValue(json['status'] as String?),
      projectName: projectName ?? json['project_name'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: _toDate(json['created_at']),
      updatedAt: _toDate(json['updated_at']),
    );
  }

  /// JSON payload for an insert/update. Excludes server-managed columns
  /// (id, created_at, updated_at) and the read-only joined project name.
  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'project_id': projectId,
        'quarter': quarter,
        'year': year,
        'completion_pct': completionPct,
        'work_description': workDescription,
        'funds_received': fundsReceived,
        'funds_utilized': fundsUtilized,
        'status': status.value,
        if (createdBy != null) 'created_by': createdBy,
      };

  ReraReport copyWith({
    String? id,
    String? companyId,
    String? projectId,
    int? quarter,
    int? year,
    double? completionPct,
    String? workDescription,
    double? fundsReceived,
    double? fundsUtilized,
    ReraReportStatus? status,
    String? projectName,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReraReport(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      quarter: quarter ?? this.quarter,
      year: year ?? this.year,
      completionPct: completionPct ?? this.completionPct,
      workDescription: workDescription ?? this.workDescription,
      fundsReceived: fundsReceived ?? this.fundsReceived,
      fundsUtilized: fundsUtilized ?? this.fundsUtilized,
      status: status ?? this.status,
      projectName: projectName ?? this.projectName,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Lightweight project reference used by the dropdown in the report form.
@immutable
class ReraProjectRef {
  final String id;
  final String name;

  const ReraProjectRef({required this.id, required this.name});

  factory ReraProjectRef.fromJson(Map<String, dynamic> json) => ReraProjectRef(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Untitled project',
      );
}

/// A placeholder geotagged site photo for the RERA photo timeline.
///
/// The dedicated project-photos table does not exist yet (Phase 3+). This model
/// is shaped so the timeline screen can later be wired to a real
/// `project_photos` source without changing the UI. For now the repository
/// returns an empty list and the screen shows an informative empty state.
@immutable
class ReraTimelinePhoto {
  final String id;
  final String projectId;
  final String? caption;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final DateTime capturedAt;

  const ReraTimelinePhoto({
    required this.id,
    required this.projectId,
    this.caption,
    this.imageUrl,
    this.latitude,
    this.longitude,
    required this.capturedAt,
  });

  bool get hasGeotag => latitude != null && longitude != null;

  String get geotagLabel => hasGeotag
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : 'No location';
}

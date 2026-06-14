import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Severity of a snag (defect).
enum SnagPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  critical('critical', 'Critical');

  final String value;
  final String label;
  const SnagPriority(this.value, this.label);

  static SnagPriority fromValue(String? v) => SnagPriority.values.firstWhere(
        (p) => p.value == v,
        orElse: () => SnagPriority.medium,
      );

  Color get color => switch (this) {
        SnagPriority.low => AppColors.textHint,
        SnagPriority.medium => AppColors.info,
        SnagPriority.high => AppColors.warning,
        SnagPriority.critical => AppColors.error,
      };
}

/// Lifecycle status of a snag.
enum SnagStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In Progress'),
  resolved('resolved', 'Resolved'),
  closed('closed', 'Closed');

  final String value;
  final String label;
  const SnagStatus(this.value, this.label);

  static SnagStatus fromValue(String? v) => SnagStatus.values.firstWhere(
        (s) => s.value == v,
        orElse: () => SnagStatus.open,
      );

  bool get isResolved => this == resolved || this == closed;

  Color get color => switch (this) {
        SnagStatus.open => AppColors.error,
        SnagStatus.inProgress => AppColors.warning,
        SnagStatus.resolved => AppColors.success,
        SnagStatus.closed => AppColors.statusOnHold,
      };
}

/// A snag (defect / punch-list item) raised against a project, optionally
/// linked to a failed checklist item.
///
/// Maps to `snags` (migration 054_qa_qc.sql).
class Snag {
  final String id;
  final String companyId;
  final String projectId;
  final String? checklistItemId;
  final String title;
  final String? description;
  final String? location;
  final SnagPriority priority;
  final SnagStatus status;
  final String? raisedBy;
  final String? assignedTo;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Optional photo lists hydrated by the repository for the detail screen.
  final List<SnagPhoto> photos;

  const Snag({
    required this.id,
    required this.companyId,
    required this.projectId,
    this.checklistItemId,
    required this.title,
    this.description,
    this.location,
    this.priority = SnagPriority.medium,
    this.status = SnagStatus.open,
    this.raisedBy,
    this.assignedTo,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNotes,
    this.createdAt,
    this.updatedAt,
    this.photos = const [],
  });

  List<SnagPhoto> get beforePhotos =>
      photos.where((p) => p.kind == SnagPhotoKind.before).toList();
  List<SnagPhoto> get afterPhotos =>
      photos.where((p) => p.kind == SnagPhotoKind.after).toList();

  factory Snag.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['snag_photos'];
    return Snag(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      checklistItemId: json['checklist_item_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      location: json['location'] as String?,
      priority: SnagPriority.fromValue(json['priority'] as String?),
      status: SnagStatus.fromValue(json['status'] as String?),
      raisedBy: json['raised_by'] as String?,
      assignedTo: json['assigned_to'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      resolutionNotes: json['resolution_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      photos: rawPhotos is List
          ? rawPhotos
              .map((e) => SnagPhoto.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'project_id': projectId,
        if (checklistItemId != null) 'checklist_item_id': checklistItemId,
        'title': title,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
        'priority': priority.value,
        'status': status.value,
        if (raisedBy != null) 'raised_by': raisedBy,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (resolvedBy != null) 'resolved_by': resolvedBy,
        if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
        if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
      };

  Snag copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? checklistItemId,
    String? title,
    String? description,
    String? location,
    SnagPriority? priority,
    SnagStatus? status,
    String? raisedBy,
    String? assignedTo,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SnagPhoto>? photos,
  }) {
    return Snag(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      checklistItemId: checklistItemId ?? this.checklistItemId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      raisedBy: raisedBy ?? this.raisedBy,
      assignedTo: assignedTo ?? this.assignedTo,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photos: photos ?? this.photos,
    );
  }
}

/// Whether a photo documents the defect (before) or the fix (after).
enum SnagPhotoKind {
  before('before', 'Before'),
  after('after', 'After');

  final String value;
  final String label;
  const SnagPhotoKind(this.value, this.label);

  static SnagPhotoKind fromValue(String? v) => SnagPhotoKind.values.firstWhere(
        (k) => k.value == v,
        orElse: () => SnagPhotoKind.before,
      );
}

/// A before/after photo for a snag, stored in the 'snags' Storage bucket.
///
/// Maps to `snag_photos`.
class SnagPhoto {
  final String id;
  final String companyId;
  final String snagId;
  final String photoUrl;
  final String? storagePath;
  final SnagPhotoKind kind;
  final String? uploadedBy;
  final DateTime? createdAt;

  const SnagPhoto({
    required this.id,
    required this.companyId,
    required this.snagId,
    required this.photoUrl,
    this.storagePath,
    this.kind = SnagPhotoKind.before,
    this.uploadedBy,
    this.createdAt,
  });

  factory SnagPhoto.fromJson(Map<String, dynamic> json) {
    return SnagPhoto(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      snagId: json['snag_id'] as String,
      photoUrl: json['photo_url'] as String? ?? '',
      storagePath: json['storage_path'] as String?,
      kind: SnagPhotoKind.fromValue(json['kind'] as String?),
      uploadedBy: json['uploaded_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'snag_id': snagId,
        'photo_url': photoUrl,
        if (storagePath != null) 'storage_path': storagePath,
        'kind': kind.value,
        if (uploadedBy != null) 'uploaded_by': uploadedBy,
      };
}

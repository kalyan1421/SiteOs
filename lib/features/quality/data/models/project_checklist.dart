import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Status of an entire project checklist.
enum ProjectChecklistStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed');

  final String value;
  final String label;
  const ProjectChecklistStatus(this.value, this.label);

  static ProjectChecklistStatus fromValue(String? v) =>
      ProjectChecklistStatus.values.firstWhere(
        (s) => s.value == v,
        orElse: () => ProjectChecklistStatus.open,
      );

  Color get color => switch (this) {
        ProjectChecklistStatus.open => AppColors.statusPending,
        ProjectChecklistStatus.inProgress => AppColors.info,
        ProjectChecklistStatus.completed => AppColors.success,
      };
}

/// A checklist instance applied to a specific project, optionally created from
/// a [ChecklistTemplate].
///
/// Maps to `project_checklists` (migration 054_qa_qc.sql).
class ProjectChecklist {
  final String id;
  final String companyId;
  final String projectId;
  final String? templateId;
  final String name;
  final ProjectChecklistStatus status;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Optional aggregate counts (not a DB column — set by the repository when it
  /// joins item counts). Used for progress chips in lists.
  final int totalItems;
  final int completedItems;

  const ProjectChecklist({
    required this.id,
    required this.companyId,
    required this.projectId,
    this.templateId,
    required this.name,
    this.status = ProjectChecklistStatus.open,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.totalItems = 0,
    this.completedItems = 0,
  });

  double get progress =>
      totalItems == 0 ? 0 : completedItems / totalItems;

  factory ProjectChecklist.fromJson(Map<String, dynamic> json) {
    return ProjectChecklist(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      templateId: json['template_id'] as String?,
      name: json['name'] as String? ?? '',
      status: ProjectChecklistStatus.fromValue(json['status'] as String?),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'project_id': projectId,
        if (templateId != null) 'template_id': templateId,
        'name': name,
        'status': status.value,
        if (createdBy != null) 'created_by': createdBy,
      };

  ProjectChecklist copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? templateId,
    String? name,
    ProjectChecklistStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalItems,
    int? completedItems,
  }) {
    return ProjectChecklist(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalItems: totalItems ?? this.totalItems,
      completedItems: completedItems ?? this.completedItems,
    );
  }
}

/// Pass/fail/na status of a single checklist line item.
enum ChecklistItemStatus {
  pending('pending', 'Pending'),
  pass('pass', 'Pass'),
  fail('fail', 'Fail'),
  na('na', 'N/A');

  final String value;
  final String label;
  const ChecklistItemStatus(this.value, this.label);

  static ChecklistItemStatus fromValue(String? v) =>
      ChecklistItemStatus.values.firstWhere(
        (s) => s.value == v,
        orElse: () => ChecklistItemStatus.pending,
      );

  Color get color => switch (this) {
        ChecklistItemStatus.pending => AppColors.textHint,
        ChecklistItemStatus.pass => AppColors.success,
        ChecklistItemStatus.fail => AppColors.error,
        ChecklistItemStatus.na => AppColors.statusOnHold,
      };

  IconData get icon => switch (this) {
        ChecklistItemStatus.pending => Icons.radio_button_unchecked,
        ChecklistItemStatus.pass => Icons.check_circle,
        ChecklistItemStatus.fail => Icons.cancel,
        ChecklistItemStatus.na => Icons.remove_circle,
      };
}

/// A single pass/fail/na line in a [ProjectChecklist].
///
/// Maps to `checklist_items`.
class ChecklistItem {
  final String id;
  final String companyId;
  final String projectChecklistId;
  final String title;
  final String? description;
  final ChecklistItemStatus status;
  final String? notes;
  final int sortOrder;
  final String? checkedBy;
  final DateTime? checkedAt;

  const ChecklistItem({
    required this.id,
    required this.companyId,
    required this.projectChecklistId,
    required this.title,
    this.description,
    this.status = ChecklistItemStatus.pending,
    this.notes,
    this.sortOrder = 0,
    this.checkedBy,
    this.checkedAt,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectChecklistId: json['project_checklist_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: ChecklistItemStatus.fromValue(json['status'] as String?),
      notes: json['notes'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      checkedBy: json['checked_by'] as String?,
      checkedAt: json['checked_at'] != null
          ? DateTime.tryParse(json['checked_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'project_checklist_id': projectChecklistId,
        'title': title,
        if (description != null) 'description': description,
        'status': status.value,
        if (notes != null) 'notes': notes,
        'sort_order': sortOrder,
        if (checkedBy != null) 'checked_by': checkedBy,
        if (checkedAt != null) 'checked_at': checkedAt!.toIso8601String(),
      };

  ChecklistItem copyWith({
    String? id,
    String? companyId,
    String? projectChecklistId,
    String? title,
    String? description,
    ChecklistItemStatus? status,
    String? notes,
    int? sortOrder,
    String? checkedBy,
    DateTime? checkedAt,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectChecklistId: projectChecklistId ?? this.projectChecklistId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      checkedBy: checkedBy ?? this.checkedBy,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
}

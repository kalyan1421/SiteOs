/// A reusable QA/QC checklist template (admin-managed, per company).
///
/// Maps to `checklist_templates` (migration 054_qa_qc.sql).
class ChecklistTemplate {
  final String id;
  final String companyId;
  final String name;
  final String? description;
  final String? category;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChecklistTemplate({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.category,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) {
    return ChecklistTemplate(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      isActive: json['is_active'] as bool? ?? true,
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
        'name': name,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        'is_active': isActive,
        if (createdBy != null) 'created_by': createdBy,
      };

  ChecklistTemplate copyWith({
    String? id,
    String? companyId,
    String? name,
    String? description,
    String? category,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChecklistTemplate(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A single ordered line in a [ChecklistTemplate].
///
/// Maps to `checklist_template_items`.
class ChecklistTemplateItem {
  final String id;
  final String companyId;
  final String templateId;
  final String title;
  final String? description;
  final int sortOrder;
  final DateTime? createdAt;

  const ChecklistTemplateItem({
    required this.id,
    required this.companyId,
    required this.templateId,
    required this.title,
    this.description,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory ChecklistTemplateItem.fromJson(Map<String, dynamic> json) {
    return ChecklistTemplateItem(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      templateId: json['template_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'template_id': templateId,
        'title': title,
        if (description != null) 'description': description,
        'sort_order': sortOrder,
      };

  ChecklistTemplateItem copyWith({
    String? id,
    String? companyId,
    String? templateId,
    String? title,
    String? description,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return ChecklistTemplateItem(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

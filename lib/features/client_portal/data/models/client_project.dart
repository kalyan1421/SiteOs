/// A project as seen by a client user (read-only).
///
/// Maps to the subset of `public.projects` columns a client is allowed to read
/// via RLS (migration 058). Plain Dart class — no codegen.
class ClientProject {
  final String id;
  final String name;
  final String? description;
  final String? location;
  final String? clientName;
  final String? projectType;
  final String status;
  final int progress; // 0–100
  final DateTime? startDate;
  final DateTime? endDate;
  final num? budget;

  const ClientProject({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.clientName,
    this.projectType,
    required this.status,
    required this.progress,
    this.startDate,
    this.endDate,
    this.budget,
  });

  factory ClientProject.fromJson(Map<String, dynamic> json) {
    return ClientProject(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled project',
      description: json['description'] as String?,
      location: json['location'] as String?,
      clientName: json['client_name'] as String?,
      projectType: json['project_type'] as String?,
      status: json['status'] as String? ?? 'planning',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      budget: json['budget'] as num?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'location': location,
        'client_name': clientName,
        'project_type': projectType,
        'status': status,
        'progress': progress,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'budget': budget,
      };

  ClientProject copyWith({
    String? id,
    String? name,
    String? description,
    String? location,
    String? clientName,
    String? projectType,
    String? status,
    int? progress,
    DateTime? startDate,
    DateTime? endDate,
    num? budget,
  }) {
    return ClientProject(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      clientName: clientName ?? this.clientName,
      projectType: projectType ?? this.projectType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
    );
  }

  /// Human label for the project status.
  String get statusLabel => switch (status) {
        'planning' => 'Planning',
        'in_progress' => 'In Progress',
        'on_hold' => 'On Hold',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        _ => status,
      };

  double get progressFraction => (progress.clamp(0, 100)) / 100.0;

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

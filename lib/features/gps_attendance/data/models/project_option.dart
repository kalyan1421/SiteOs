/// Lightweight {id, name} pair for project pickers in the GPS attendance
/// screens. Kept self-contained so this feature does not depend on the
/// projects feature's full model.
class ProjectOption {
  final String id;
  final String name;

  const ProjectOption({required this.id, required this.name});

  factory ProjectOption.fromJson(Map<String, dynamic> json) {
    return ProjectOption(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Untitled project',
    );
  }
}

/// Lightweight {id, name} pair for labour pickers on the check-in screen.
class LabourOption {
  final String id;
  final String name;

  const LabourOption({required this.id, required this.name});

  factory LabourOption.fromJson(Map<String, dynamic> json) {
    return LabourOption(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Unnamed',
    );
  }
}

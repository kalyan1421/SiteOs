/// A single GPS check-in event recorded at a project site.
///
/// Maps to the `gps_checkins` table (migration 059_gps_attendance.sql).
class GpsCheckin {
  final String id;
  final String companyId;
  final String projectId;
  final String? labourId;
  final String? userId;
  final double lat;
  final double lng;
  final double distanceM;
  final bool withinGeofence;
  final DateTime checkedInAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Joined display fields, when selected.
  final String? projectName;
  final String? labourName;

  const GpsCheckin({
    required this.id,
    required this.companyId,
    required this.projectId,
    this.labourId,
    this.userId,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.withinGeofence,
    required this.checkedInAt,
    required this.createdAt,
    required this.updatedAt,
    this.projectName,
    this.labourName,
  });

  factory GpsCheckin.fromJson(Map<String, dynamic> json) {
    return GpsCheckin(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      labourId: json['labour_id'] as String?,
      userId: json['user_id'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0,
      withinGeofence: json['within_geofence'] as bool? ?? false,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      projectName: json['projects']?['name'] as String?,
      labourName: json['labour']?['name'] as String?,
    );
  }

  /// Payload for insert. Excludes server-managed columns.
  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'project_id': projectId,
      if (labourId != null) 'labour_id': labourId,
      if (userId != null) 'user_id': userId,
      'lat': lat,
      'lng': lng,
      'distance_m': distanceM,
      'within_geofence': withinGeofence,
      'checked_in_at': checkedInAt.toUtc().toIso8601String(),
    };
  }

  GpsCheckin copyWith({
    String? id,
    String? companyId,
    String? projectId,
    String? labourId,
    String? userId,
    double? lat,
    double? lng,
    double? distanceM,
    bool? withinGeofence,
    DateTime? checkedInAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? projectName,
    String? labourName,
  }) {
    return GpsCheckin(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      labourId: labourId ?? this.labourId,
      userId: userId ?? this.userId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      distanceM: distanceM ?? this.distanceM,
      withinGeofence: withinGeofence ?? this.withinGeofence,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectName: projectName ?? this.projectName,
      labourName: labourName ?? this.labourName,
    );
  }
}

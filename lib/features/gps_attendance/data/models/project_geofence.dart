import 'dart:math' as math;

/// A geofence anchored to a project — a centre point (lat/lng) and an
/// allowed radius in metres. Check-ins are only permitted within this radius.
///
/// Maps to the `project_geofences` table (migration 059_gps_attendance.sql).
class ProjectGeofence {
  final String id;
  final String companyId;
  final String projectId;
  final double lat;
  final double lng;
  final int radiusM;
  final String? label;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Joined project name (from `projects(name)` select), when available.
  final String? projectName;

  const ProjectGeofence({
    required this.id,
    required this.companyId,
    required this.projectId,
    required this.lat,
    required this.lng,
    this.radiusM = 200,
    this.label,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.projectName,
  });

  factory ProjectGeofence.fromJson(Map<String, dynamic> json) {
    return ProjectGeofence(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      projectId: json['project_id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusM: (json['radius_m'] as num?)?.toInt() ?? 200,
      label: json['label'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      projectName: json['projects']?['name'] as String?,
    );
  }

  /// Payload for insert/upsert. Excludes server-managed columns.
  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'project_id': projectId,
      'lat': lat,
      'lng': lng,
      'radius_m': radiusM,
      if (label != null) 'label': label,
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  ProjectGeofence copyWith({
    String? id,
    String? companyId,
    String? projectId,
    double? lat,
    double? lng,
    int? radiusM,
    String? label,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? projectName,
  }) {
    return ProjectGeofence(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      projectId: projectId ?? this.projectId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusM: radiusM ?? this.radiusM,
      label: label ?? this.label,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectName: projectName ?? this.projectName,
    );
  }

  /// Haversine distance in metres from this geofence centre to ([fromLat],
  /// [fromLng]). Pure Dart so it works offline and needs no platform plugin.
  double distanceMetresTo(double fromLat, double fromLng) {
    return haversineMetres(lat, lng, fromLat, fromLng);
  }

  /// True when the supplied position is inside the allowed radius.
  bool contains(double fromLat, double fromLng) {
    return distanceMetresTo(fromLat, fromLng) <= radiusM;
  }

  /// Great-circle distance between two WGS84 points, in metres.
  static double haversineMetres(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _toRad(double deg) => deg * (math.pi / 180.0);
}

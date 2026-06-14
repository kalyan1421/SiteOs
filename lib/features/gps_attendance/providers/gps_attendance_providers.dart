import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/gps_checkin.dart';
import '../data/models/project_geofence.dart';
import '../data/models/project_option.dart';
import '../data/repositories/gps_attendance_repository.dart';
import '../data/services/location_service.dart';

/// Repository singleton for GPS attendance.
final gpsAttendanceRepositoryProvider =
    Provider<GpsAttendanceRepository>((ref) => GpsAttendanceRepository());

/// Device location service singleton.
final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// Active projects for the picker dropdowns.
final gpsProjectsProvider = FutureProvider<List<ProjectOption>>((ref) async {
  final repo = ref.watch(gpsAttendanceRepositoryProvider);
  return repo.getProjects();
});

/// Active labour assigned to [projectId], for the check-in picker.
final labourForProjectProvider =
    FutureProvider.family<List<LabourOption>, String>((ref, projectId) async {
  final repo = ref.watch(gpsAttendanceRepositoryProvider);
  return repo.getLabourForProject(projectId);
});

/// The geofence configured for [projectId], or null when unset.
final geofenceForProjectProvider =
    FutureProvider.family<ProjectGeofence?, String>((ref, projectId) async {
  final repo = ref.watch(gpsAttendanceRepositoryProvider);
  return repo.getGeofenceForProject(projectId);
});

/// All geofences for the current company (admin overview list).
final geofencesProvider = FutureProvider<List<ProjectGeofence>>((ref) async {
  final repo = ref.watch(gpsAttendanceRepositoryProvider);
  return repo.getGeofences();
});

/// Recent check-ins, optionally scoped to a project (null = all).
final recentCheckinsProvider =
    FutureProvider.family<List<GpsCheckin>, String?>((ref, projectId) async {
  final repo = ref.watch(gpsAttendanceRepositoryProvider);
  return repo.getRecentCheckins(projectId: projectId);
});

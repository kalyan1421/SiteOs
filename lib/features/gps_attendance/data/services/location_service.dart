import 'package:geolocator/geolocator.dart';

/// A fix resolved from the device GPS.
class DeviceLocation {
  final double lat;
  final double lng;
  final double accuracyM;

  const DeviceLocation({
    required this.lat,
    required this.lng,
    required this.accuracyM,
  });
}

/// Raised when a location read fails for a user-actionable reason. [message]
/// is safe to show in a SnackBar.
class LocationFailure implements Exception {
  final String message;

  /// True when the failure is permanent (permission permanently denied) and
  /// the user must open app settings to recover.
  final bool openSettingsRequired;

  const LocationFailure(this.message, {this.openSettingsRequired = false});

  @override
  String toString() => message;
}

/// Thin wrapper over `geolocator`. Handles the service-enabled check and the
/// permission flow, then returns a single best-effort fix.
class LocationService {
  const LocationService();

  /// Ensures location services + permission are available, then returns the
  /// current position. Throws [LocationFailure] with a user-facing message
  /// on any recoverable problem.
  Future<DeviceLocation> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure(
        'Location services are turned off. Enable GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Location permission is permanently denied. Enable it in Settings.',
        openSettingsRequired: true,
      );
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        'Location permission was denied. Allow access to check in.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return DeviceLocation(
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
      );
    } catch (e) {
      throw const LocationFailure(
        "Couldn't get a GPS fix. Move to an open area and try again.",
      );
    }
  }

  /// Opens the OS app-settings page so the user can grant location permission.
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}

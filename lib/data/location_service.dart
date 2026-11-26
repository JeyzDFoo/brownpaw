import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

typedef LatLng = ({double latitude, double longitude});

/// Whether Brownpaw can read the device location.
enum LocationAccess {
  /// Granted: positions can be read without asking.
  granted,

  /// Not asked yet: asking shows the system prompt.
  askable,

  /// Turned off, refused for good, or not supported here.
  unavailable,
}

/// The device's location, behind an interface so screens can be tested.
class LocationService {
  const LocationService();

  Future<LocationAccess> access() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.unavailable;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.denied => LocationAccess.askable,
        _ => LocationAccess.unavailable,
      };
    } catch (_) {
      return LocationAccess.unavailable;
    }
  }

  /// Shows the system prompt. Returns the access the person chose.
  Future<LocationAccess> ask() async {
    try {
      await Geolocator.requestPermission();
    } catch (_) {
      return LocationAccess.unavailable;
    }
    return access();
  }

  /// The current position, or null when access isn't granted. Never prompts.
  Future<LatLng?> currentPosition() async {
    if (await access() != LocationAccess.granted) return null;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (latitude: p.latitude, longitude: p.longitude);
    } catch (_) {
      // No fix in time (in a canyon, say): the last known spot is close
      // enough for sorting by distance.
      try {
        final p = await Geolocator.getLastKnownPosition();
        return p == null
            ? null
            : (latitude: p.latitude, longitude: p.longitude);
      } catch (_) {
        return null;
      }
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

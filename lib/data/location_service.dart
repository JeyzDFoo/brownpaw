import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

typedef LatLng = ({double latitude, double longitude});

/// Whether Brownpaw can read the device location.
enum LocationAccess {
  /// Granted: positions can be read without asking.
  granted,

  /// Not asked yet: asking shows the system prompt.
  askable,

  /// The paddler said no. The system won't ask again, so only Settings
  /// can turn it back on.
  denied,

  /// Location Services are off for the whole phone.
  off,

  /// Not supported here, or the platform failed to answer.
  unavailable,
}

/// The device's location, behind an interface so screens can be tested.
class LocationService {
  const LocationService();

  Future<LocationAccess> access() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.off;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.denied => LocationAccess.askable,
        LocationPermission.deniedForever => LocationAccess.denied,
        _ => LocationAccess.unavailable,
      };
    } catch (_) {
      return LocationAccess.unavailable;
    }
  }

  /// Shows the system prompt. Returns the access the person chose.
  Future<LocationAccess> ask() async {
    try {
      final chose = await Geolocator.requestPermission();
      // Android lets an app ask twice; a single "no" there reads as
      // askable again. Treat any "no" as the paddler's answer for now.
      if (chose == LocationPermission.denied) return LocationAccess.denied;
    } catch (_) {
      return LocationAccess.unavailable;
    }
    return access();
  }

  /// The current position, or null when access isn't granted. Never prompts.
  ///
  /// Falls back to the last known position when a fresh fix is slow, as
  /// it often is in a canyon or a car.
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
      return lastKnownPosition();
    }
  }

  /// Where the device last was, at once, without a fresh fix. Null when
  /// unknown, unsupported (the web) or not allowed.
  Future<LatLng?> lastKnownPosition() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null) return null;
      return (latitude: p.latitude, longitude: p.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Opens the place where [access] can be fixed: the phone's Location
  /// Services switch when it's [LocationAccess.off], otherwise Brownpaw's
  /// own settings page.
  Future<void> openSettings(LocationAccess access) async {
    try {
      if (access == LocationAccess.off) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      // Nothing more to do; the message already says where to go.
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

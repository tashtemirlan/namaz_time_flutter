import 'dart:math' as math;

/// Calculates the Qibla direction (bearing to the Kaaba in Mecca).
class QiblaService {
  /// Kaaba coordinates
  static const double _meccaLat = 21.4225;
  static const double _meccaLng = 39.8262;

  /// Compute the bearing from [lat, lng] to Mecca in degrees (0–360).
  /// 0° = North, 90° = East, 180° = South, 270° = West.
  static double getQiblaBearing(double userLat, double userLng) {
    final lat1 = _toRad(userLat);
    final lat2 = _toRad(_meccaLat);
    final dLng = _toRad(_meccaLng - userLng);

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final bearing = math.atan2(y, x);
    return (_toDeg(bearing) + 360) % 360;
  }

  static double _toRad(double deg) => deg * math.pi / 180;
  static double _toDeg(double rad) => rad * 180 / math.pi;
}

import 'package:dio/dio.dart';
import '../models/prayer_time_model.dart';
import '../models/location_model.dart';

class PrayerTimesRepository {
  final Dio _dio;

  PrayerTimesRepository()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));

  // ─── Muftiyat.kg (Kyrgyzstan) ────────────────────────────────────────────

  /// Fetch prayer times from muftiyat.kg by location code.
  /// [date] defaults to today if omitted.
  Future<DailyPrayerTimes> fetchKgByCode({
    required int locationCode,
    String lang = 'ru',
    DateTime? date,
  }) async {
    final dateStr = _formatMuftiyat(date ?? DateTime.now());
    final url =
        'https://muftiyat.kg/$lang/api/v1/calendar/$locationCode/?start=$dateStr&end=$dateStr';
    return _fetchMuftiyat(url);
  }

  /// Fetch prayer times from muftiyat.kg by coordinates.
  /// [date] defaults to today if omitted.
  Future<DailyPrayerTimes> fetchKgByCoords({
    required double lat,
    required double lng,
    String lang = 'ru',
    DateTime? date,
  }) async {
    final dateStr = _formatMuftiyat(date ?? DateTime.now());
    final url =
        'https://muftiyat.kg/$lang/api/v1/calendar/?lat=${lat.toStringAsFixed(6)}&lng=${lng.toStringAsFixed(6)}&start=$dateStr&end=$dateStr';
    return _fetchMuftiyat(url);
  }

  Future<DailyPrayerTimes> _fetchMuftiyat(String url) async {
    try {
      final response = await _dio.get(url);
      final data = response.data;

      // Response can be List or Map containing List
      List<dynamic> items;
      if (data is List) {
        items = data;
      } else if (data is Map) {
        items = data['data'] as List<dynamic>? ??
                data['results'] as List<dynamic>? ??
                [data];
      } else {
        throw Exception('Unexpected muftiyat.kg response format');
      }

      if (items.isEmpty) throw Exception('Empty response from muftiyat.kg');
      return DailyPrayerTimes.fromMuftiyat(
          Map<String, dynamic>.from(items.first as Map));
    } on DioException catch (e) {
      throw Exception('Muftiyat.kg request failed: ${e.message}');
    }
  }

  // ─── AlAdhan (Worldwide) ─────────────────────────────────────────────────

  /// Fetch prayer times from AlAdhan by coordinates.
  /// method=2 → ISNA, method=3 → MWL, method=4 → Umm Al-Qura (Mecca).
  /// [date] defaults to today if omitted.
  Future<DailyPrayerTimes> fetchAlAdhanByCoords({
    required double lat,
    required double lng,
    int method = 3,
    DateTime? date,
  }) async {
    try {
      final target = date ?? DateTime.now();
      // Use noon of the target day so the timestamp lands firmly within that
      // calendar day regardless of the device's UTC offset.
      final noon = DateTime(target.year, target.month, target.day, 12, 0);
      final timestamp = (noon.millisecondsSinceEpoch / 1000).round();
      final url =
          'https://api.aladhan.com/v1/timings/$timestamp?latitude=$lat&longitude=$lng&method=$method';
      final response = await _dio.get(url);
      final body = response.data as Map<String, dynamic>;
      final dataMap = body['data'] as Map<String, dynamic>;
      final timings = dataMap['timings'] as Map<String, dynamic>;
      final dateMap = dataMap['date'] as Map<String, dynamic>?;
      final hijriMap = dateMap?['hijri'] as Map<String, dynamic>?;
      final dateStr = dateMap?['gregorian']?['date']?.toString() ?? _formatIso(target);

      return DailyPrayerTimes.fromAlAdhan(
        timings, dateStr,
        hijriMap,
      );
    } on DioException catch (e) {
      throw Exception('AlAdhan request failed: ${e.message}');
    }
  }

  // ─── Dispatch (decides which API to call) ────────────────────────────────

  /// Fetch prayer times for the given location.
  /// [date] defaults to today if omitted — pass tomorrow's date to pre-fetch.
  Future<DailyPrayerTimes> fetchForLocation(
    AppLocation location, {
    DateTime? date,
  }) async {
    if (location.isKyrgyzstan) {
      if (location.kgLocationCode != null) {
        return fetchKgByCode(locationCode: location.kgLocationCode!, date: date);
      } else if (location.latitude != null && location.longitude != null) {
        return fetchKgByCoords(
            lat: location.latitude!, lng: location.longitude!, date: date);
      }
    }
    // Worldwide: use AlAdhan with coordinates
    if (location.latitude != null && location.longitude != null) {
      return fetchAlAdhanByCoords(
          lat: location.latitude!, lng: location.longitude!, date: date);
    }
    throw Exception('No coordinates or location code available');
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Format a date as "DD-MM-YYYY" (muftiyat.kg format).
  static String _formatMuftiyat(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd-$mm-${date.year}';
  }

  /// Format a date as "YYYY-MM-DD".
  static String _formatIso(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }
}

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

  /// Fetch today's prayer times from muftiyat.kg by location code.
  Future<DailyPrayerTimes> fetchKgByCode({
    required int locationCode,
    String lang = 'ru',
  }) async {
    final today = _todayFormatted(); // "DD-MM-YYYY"
    final url =
        'https://muftiyat.kg/$lang/api/v1/calendar/$locationCode/?start=$today&end=$today';
    return _fetchMuftiyat(url);
  }

  /// Fetch today's prayer times from muftiyat.kg by coordinates.
  Future<DailyPrayerTimes> fetchKgByCoords({
    required double lat,
    required double lng,
    String lang = 'ru',
  }) async {
    final today = _todayFormatted();
    final url =
        'https://muftiyat.kg/$lang/api/v1/calendar/?lat=${lat.toStringAsFixed(6)}&lng=${lng.toStringAsFixed(6)}&start=$today&end=$today';
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

  /// Fetch today's prayer times from AlAdhan by coordinates.
  /// method=2 → ISNA, method=3 → MWL, method=4 → Umm Al-Qura (Mecca)
  Future<DailyPrayerTimes> fetchAlAdhanByCoords({
    required double lat,
    required double lng,
    int method = 3,
  }) async {
    try {
      final timestamp =
          (DateTime.now().millisecondsSinceEpoch / 1000).round();
      final url =
          'https://api.aladhan.com/v1/timings/$timestamp?latitude=$lat&longitude=$lng&method=$method';
      final response = await _dio.get(url);
      final body = response.data as Map<String, dynamic>;
      final dataMap = body['data'] as Map<String, dynamic>;
      final timings = dataMap['timings'] as Map<String, dynamic>;
      final dateMap = dataMap['date'] as Map<String, dynamic>?;
      final hijriMap = dateMap?['hijri'] as Map<String, dynamic>?;
      final dateStr = dateMap?['gregorian']?['date']?.toString() ?? _todayIso();

      return DailyPrayerTimes.fromAlAdhan(
        timings, dateStr,
        hijriMap,
      );
    } on DioException catch (e) {
      throw Exception('AlAdhan request failed: ${e.message}');
    }
  }

  // ─── Dispatch (decides which API to call) ────────────────────────────────

  Future<DailyPrayerTimes> fetchForLocation(AppLocation location) async {
    if (location.isKyrgyzstan) {
      if (location.kgLocationCode != null) {
        return fetchKgByCode(locationCode: location.kgLocationCode!);
      } else if (location.latitude != null && location.longitude != null) {
        return fetchKgByCoords(lat: location.latitude!, lng: location.longitude!);
      }
    }
    // Worldwide: use AlAdhan with coordinates
    if (location.latitude != null && location.longitude != null) {
      return fetchAlAdhanByCoords(
          lat: location.latitude!, lng: location.longitude!);
    }
    throw Exception('No coordinates or location code available');
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Format today as "DD-MM-YYYY" (muftiyat.kg format)
  static String _todayFormatted() {
    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    return '$dd-$mm-$yyyy';
  }

  /// Format today as "YYYY-MM-DD"
  static String _todayIso() {
    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    return '$yyyy-$mm-$dd';
  }
}

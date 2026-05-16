/// Normalized prayer times for one day.
class DailyPrayerTimes {
  final String date;        // "2026-05-15"
  final String fajr;        // "04:12"
  final String sunrise;     // "05:47"
  final String dhuhr;       // "12:45"
  final String asr;         // "16:30"
  final String maghrib;     // "19:43"
  final String isha;        // "21:18"
  final HijriDate? hijri;

  const DailyPrayerTimes({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.hijri,
  });

  /// Ordered list for UI display (sunrise included as an informational row)
  List<PrayerEntry> get prayers => [
    PrayerEntry(key: 'fajr',    time: fajr),
    PrayerEntry(key: 'sunrise', time: sunrise, isInformational: true),
    PrayerEntry(key: 'dhuhr',   time: dhuhr),
    PrayerEntry(key: 'asr',     time: asr),
    PrayerEntry(key: 'maghrib', time: maghrib),
    PrayerEntry(key: 'isha',    time: isha),
  ];

  /// Factory from muftiyat.kg API response item
  factory DailyPrayerTimes.fromMuftiyat(Map<String, dynamic> json) {
    final nested = json['prayertimes'];
    final source = nested is List && nested.isNotEmpty && nested.first is Map
        ? Map<String, dynamic>.from(nested.first as Map)
        : json;

    return DailyPrayerTimes(
      date:    source['date']?.toString() ?? json['date']?.toString() ?? '',
      fajr:    _normalizeTime(source['fajr']    ?? source['imsak'] ?? source['subh'] ?? ''),
      sunrise: _normalizeTime(source['sunrise'] ?? source['shuruk'] ?? ''),
      dhuhr:   _normalizeTime(source['dhuhr']   ?? source['zuhr']   ?? ''),
      asr:     _normalizeTime(source['asr']     ?? ''),
      maghrib: _normalizeTime(source['maghrib'] ?? source['iftar']  ?? ''),
      isha:    _normalizeTime(source['isha']    ?? source['kupton']  ?? ''),
    );
  }

  /// Factory from AlAdhan API timings object
  factory DailyPrayerTimes.fromAlAdhan(
    Map<String, dynamic> timings,
    String date, [
    Map<String, dynamic>? hijriJson,
  ]) {
    return DailyPrayerTimes(
      date:    date,
      fajr:    _normalizeTime(timings['Fajr']    ?? ''),
      sunrise: _normalizeTime(timings['Sunrise'] ?? ''),
      dhuhr:   _normalizeTime(timings['Dhuhr']   ?? ''),
      asr:     _normalizeTime(timings['Asr']     ?? ''),
      maghrib: _normalizeTime(timings['Maghrib'] ?? ''),
      isha:    _normalizeTime(timings['Isha']    ?? ''),
      hijri:   hijriJson != null ? HijriDate.fromJson(hijriJson) : null,
    );
  }

  /// Serialize to JSON for local caching (Hive).
  Map<String, dynamic> toJson() => {
    'date':    date,
    'fajr':    fajr,
    'sunrise': sunrise,
    'dhuhr':   dhuhr,
    'asr':     asr,
    'maghrib': maghrib,
    'isha':    isha,
  };

  /// Restore from a locally-cached JSON map.
  factory DailyPrayerTimes.fromCacheJson(Map<String, dynamic> json) {
    return DailyPrayerTimes(
      date:    json['date']    as String? ?? '',
      fajr:    json['fajr']    as String? ?? '',
      sunrise: json['sunrise'] as String? ?? '',
      dhuhr:   json['dhuhr']   as String? ?? '',
      asr:     json['asr']     as String? ?? '',
      maghrib: json['maghrib'] as String? ?? '',
      isha:    json['isha']    as String? ?? '',
    );
  }

  /// Strip timezone offset if present: "04:12 (+06)" → "04:12"
  static String _normalizeTime(dynamic raw) {
    final s = raw?.toString() ?? '';
    if (s.contains(' ')) return s.split(' ').first;
    return s;
  }
}

class PrayerEntry {
  final String key;            // 'fajr' | 'sunrise' | 'dhuhr' | 'asr' | 'maghrib' | 'isha'
  final String time;           // "HH:mm"
  final bool isInformational;  // true for sunrise — not a salat, shown as a time marker

  const PrayerEntry({
    required this.key,
    required this.time,
    this.isInformational = false,
  });

  /// Parse time to a DateTime on the given calendar date.
  DateTime? toDateTimeOn(DateTime date) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  /// Parse time to today's DateTime (convenience wrapper for countdown / UI).
  DateTime? toDateTime() => toDateTimeOn(DateTime.now());
}

class HijriDate {
  final int day;
  final int month;
  final int year;

  const HijriDate({required this.day, required this.month, required this.year});

  factory HijriDate.fromJson(Map<String, dynamic> json) {
    return HijriDate(
      day:   int.tryParse(json['day']?.toString()   ?? '') ?? 0,
      month: int.tryParse(json['month']?['number']?.toString() ?? json['month']?.toString() ?? '') ?? 0,
      year:  int.tryParse(json['year']?.toString()  ?? '') ?? 0,
    );
  }
}

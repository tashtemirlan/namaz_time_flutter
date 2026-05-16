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

  /// Parse time to today's DateTime for countdown
  DateTime? toDateTime() {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, m);
  }
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

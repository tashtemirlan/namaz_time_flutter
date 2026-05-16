import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/prayer_time_model.dart';
import '../models/location_model.dart';
import '../repositories/prayer_times_repository.dart';

enum PrayerLoadState { initial, loading, loaded, error }

class PrayerProvider extends ChangeNotifier {
  final PrayerTimesRepository _repo;

  DailyPrayerTimes? _times;
  PrayerLoadState _state = PrayerLoadState.initial;
  String? _errorMessage;
  Timer? _tickTimer;

  // Countdown tracking
  PrayerEntry? _nextPrayer;
  Duration _remainingTime = Duration.zero;

  DailyPrayerTimes? get times => _times;
  PrayerLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  PrayerEntry? get nextPrayer => _nextPrayer;
  Duration get remainingTime => _remainingTime;

  PrayerProvider(this._repo);

  Future<void> load(AppLocation location) async {
    _state = PrayerLoadState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _times = await _repo.fetchForLocation(location);
      _state = PrayerLoadState.loaded;
      _startCountdown();
    } catch (e) {
      _state = PrayerLoadState.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  // ─── Countdown timer ─────────────────────────────────────────────────────

  void _startCountdown() {
    _tickTimer?.cancel();
    _updateNext();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateNext();
      notifyListeners();
    });
  }

  void _updateNext() {
    if (_times == null) return;
    final now = DateTime.now();
    PrayerEntry? next;
    Duration shortest = const Duration(days: 1);

    for (final p in _times!.prayers) {
      if (p.isInformational) continue; // sunrise is not a salat — skip in countdown
      final dt = p.toDateTime();
      if (dt == null) continue;
      if (dt.isAfter(now)) {
        final diff = dt.difference(now);
        if (diff < shortest) {
          shortest = diff;
          next = p;
        }
      }
    }

    _nextPrayer = next;
    _remainingTime = next != null ? shortest : Duration.zero;
  }

  /// Whether a prayer is the currently active one (between its time and the next)
  bool isPrayerActive(PrayerEntry prayer) {
    if (_times == null) return false;
    final prayers = _times!.prayers;
    final idx = prayers.indexWhere((p) => p.key == prayer.key);
    if (idx < 0) return false;

    final now = DateTime.now();
    final pDt = prayer.toDateTime();
    if (pDt == null || pDt.isAfter(now)) return false;

    // Check if the next prayer has started yet
    if (idx + 1 < prayers.length) {
      final nextDt = prayers[idx + 1].toDateTime();
      if (nextDt != null && nextDt.isBefore(now)) return false;
    }
    return true;
  }

  /// Whether a prayer has already passed today
  bool isPrayerPassed(PrayerEntry prayer) {
    final dt = prayer.toDateTime();
    if (dt == null) return false;
    return dt.isBefore(DateTime.now()) && !isPrayerActive(prayer);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}

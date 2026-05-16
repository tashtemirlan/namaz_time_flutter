import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/prayer_time_model.dart';
import '../models/location_model.dart';
import '../repositories/prayer_times_repository.dart';
import '../global/app_settings.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Timer? _midnightTimer;

  // Channels
  static const _channelSound       = 'prayer_times_sound';
  static const _channelSilent      = 'prayer_times_silent';
  static const _channelDefaultAzan = 'prayer_times_azan';

  // Notification ID layout:
  //   Today    pre-azan reminders : 0–5
  //   Today    azan-time          : 1000–1005
  //   Tomorrow pre-azan reminders : 100–105
  //   Tomorrow azan-time          : 1100–1105
  //   Test                        : 900001
  static const _todayPreAzanBase    = 0;
  static const _todayAzanBase       = 1000;
  static const _tomorrowPreAzanBase = 100;
  static const _tomorrowAzanBase    = 1100;

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    _setLocalTimezone();

    const android = AndroidInitializationSettings('@drawable/ic_stat_namaztime');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings: settings);
    await _ensureChannels();
    _initialized = true;
  }

  static Future<void> _ensureChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelSound,
        'Prayer Times',
        description: 'Reminders for each prayer time (with sound)',
        importance: Importance.high,
        playSound: true,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelSilent,
        'Prayer Times (Silent)',
        description: 'Reminders for each prayer time (no sound)',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelDefaultAzan,
        'Prayer Times (Azan)',
        description: 'Reminders for each prayer time with default azan sound',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('azan'),
      ),
    );
  }

  static void _setLocalTimezone() {
    try {
      final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(loc).timeZoneOffset.inMinutes == offsetMinutes) {
          tz.setLocalLocation(loc);
          return;
        }
      }
    } catch (e) {
      debugPrint('NotificationService: timezone init error: $e');
    }
  }

  static Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  // ─── Public scheduling API ───────────────────────────────────────────────

  /// Schedule today's prayer notifications and pre-schedule tomorrow in
  /// background.  Caches [times] so they can be used as offline fallback.
  static Future<void> schedulePrayerNotifications(
    DailyPrayerTimes times,
    String langCode,
  ) async {
    // Always cache the freshest data we have.
    await AppSettings.cachePrayerTimesJson(times.toJson(), times.date);

    await cancelAll();
    final today = _dateOnly(DateTime.now());
    await _scheduleDayNotifications(
      times: times,
      langCode: langCode,
      forDate: today,
      preAzanIdBase: _todayPreAzanBase,
      azanIdBase: _todayAzanBase,
      now: DateTime.now(),
    );

    // Pre-schedule tomorrow in background — non-blocking, best effort.
    _prescheduleTomorrow(langCode);
  }

  /// Fetch today's prayer times and reschedule.
  /// If the network is unreachable, falls back to the last cached times and
  /// schedules notifications with a "data from [date] — open app" warning.
  static Future<void> refreshScheduleForToday() async {
    final rawLoc = AppSettings.savedLocationJson;
    if (rawLoc == null) return;

    final location = AppLocation.fromJson(rawLoc);
    final repo = PrayerTimesRepository();

    DailyPrayerTimes? times;
    bool isStale = false;

    try {
      times = await repo.fetchForLocation(location);
      // Persist fresh data for future offline use.
      await AppSettings.cachePrayerTimesJson(times.toJson(), times.date);
      isStale = false;
    } catch (e) {
      debugPrint('NotificationService: fetch failed — trying cache. $e');
      final cachedJson = AppSettings.cachedPrayerTimesJson;
      if (cachedJson != null) {
        times = DailyPrayerTimes.fromCacheJson(cachedJson);
        isStale = true;
      }
    }

    if (times == null) return; // No data at all, nothing to schedule.

    await cancelAll();
    final today = _dateOnly(DateTime.now());
    await _scheduleDayNotifications(
      times: times,
      langCode: AppSettings.language,
      forDate: today,
      preAzanIdBase: _todayPreAzanBase,
      azanIdBase: _todayAzanBase,
      now: DateTime.now(),
      stale: isStale,
      staleDate: isStale ? (AppSettings.cachedPrayerTimesDate ?? times.date) : null,
    );

    // Only pre-schedule tomorrow when we have fresh network data.
    if (!isStale) {
      _prescheduleTomorrow(AppSettings.language);
    }
  }

  /// Start automatic daily refresh via a Dart Timer (fires while app is alive).
  static void startDailyAutoRefresh() {
    _midnightTimer?.cancel();
    _scheduleNextMidnightTick();
  }

  // ─── Core scheduler ──────────────────────────────────────────────────────

  /// Schedule pre-azan reminders and exact-azan notifications for [forDate].
  /// Does NOT cancel existing notifications — callers must do that separately.
  static Future<void> _scheduleDayNotifications({
    required DailyPrayerTimes times,
    required String langCode,
    required DateTime forDate,
    required int preAzanIdBase,
    required int azanIdBase,
    required DateTime now,
    bool stale = false,
    String? staleDate,
  }) async {
    final beforeMin      = AppSettings.notifyBeforeMinutes;
    final soundOn        = AppSettings.soundEnabled;
    final azanSoundMode  = AppSettings.azanSoundMode;
    final customSoundUri = AppSettings.customSoundUri;

    final channelId   = _resolveChannelId(
        soundOn: soundOn, azanSoundMode: azanSoundMode, customSoundUri: customSoundUri);
    final channelName = _resolveChannelName(soundOn, azanSoundMode);
    await _ensureDynamicChannel(
        channelId: channelId, channelName: channelName,
        soundOn: soundOn, azanSoundMode: azanSoundMode, customSoundUri: customSoundUri);

    final details = _buildNotifDetails(
        soundOn: soundOn, azanSoundMode: azanSoundMode,
        customSoundUri: customSoundUri, channelId: channelId, channelName: channelName);

    final dateLabel = stale ? _formatDateForNotif(staleDate ?? times.date, langCode) : null;
    final prayers   = times.prayers;

    for (int i = 0; i < prayers.length; i++) {
      final prayer = prayers[i];
      if (!AppSettings.isPrayerNotifEnabled(prayer.key)) continue;

      final dt = prayer.toDateTimeOn(forDate);
      if (dt == null) continue;

      // 1) Pre-azan reminder
      if (beforeMin > 0) {
        final notifTime = dt.subtract(Duration(minutes: beforeMin));
        if (!notifTime.isBefore(now)) {
          await _plugin.zonedSchedule(
            id: preAzanIdBase + i,
            title: _prayerTitle(prayer.key, langCode),
            body: stale
                ? _prayerBodyStale(prayer.key, prayer.time, beforeMin, langCode, dateLabel!)
                : _prayerBody(prayer.key, prayer.time, beforeMin, langCode),
            scheduledDate: tz.TZDateTime.from(notifTime, tz.local),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }

      // 2) Exact azan-time notification
      if (!dt.isBefore(now)) {
        await _plugin.zonedSchedule(
          id: azanIdBase + i,
          title: _prayerTitle(prayer.key, langCode),
          body: stale
              ? _azanNowBodyStale(prayer.key, prayer.time, langCode, dateLabel!)
              : _azanNowBody(prayer.key, prayer.time, langCode),
          scheduledDate: tz.TZDateTime.from(dt, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  /// Fetch tomorrow's times and schedule them into the "tomorrow" ID range
  /// without touching today's already-scheduled notifications.
  static void _prescheduleTomorrow(String langCode) {
    () async {
      try {
        final rawLoc = AppSettings.savedLocationJson;
        if (rawLoc == null) return;
        final location = AppLocation.fromJson(rawLoc);
        final repo = PrayerTimesRepository();
        final tomorrow = _dateOnly(DateTime.now()).add(const Duration(days: 1));
        final tomorrowTimes = await repo.fetchForLocation(location, date: tomorrow);
        await _scheduleDayNotifications(
          times: tomorrowTimes,
          langCode: langCode,
          forDate: tomorrow,
          preAzanIdBase: _tomorrowPreAzanBase,
          azanIdBase: _tomorrowAzanBase,
          now: tomorrow, // treat all tomorrow's prayers as "in future"
        );
        debugPrint('NotificationService: tomorrow pre-scheduled ✓');
      } catch (e) {
        debugPrint('NotificationService: tomorrow pre-schedule failed: $e');
      }
    }();
  }

  static void _scheduleNextMidnightTick() {
    final now           = DateTime.now();
    final nextMidnight  = DateTime(now.year, now.month, now.day + 1);
    final delay         = nextMidnight.difference(now);

    _midnightTimer = Timer(delay, () async {
      try {
        await refreshScheduleForToday();
      } catch (e) {
        debugPrint('NotificationService: midnight refresh failed: $e');
      } finally {
        _scheduleNextMidnightTick();
      }
    });
  }

  static Future<void> cancelAll() async => _plugin.cancelAll();

  // ─── Test notification ───────────────────────────────────────────────────

  static Future<void> showTestNotification(String langCode) async {
    final soundOn        = AppSettings.soundEnabled;
    final azanSoundMode  = AppSettings.azanSoundMode;
    final customSoundUri = AppSettings.customSoundUri;
    final channelId   = _resolveChannelId(
        soundOn: soundOn, azanSoundMode: azanSoundMode, customSoundUri: customSoundUri);
    final channelName = _resolveChannelName(soundOn, azanSoundMode);
    await _ensureDynamicChannel(
        channelId: channelId, channelName: channelName,
        soundOn: soundOn, azanSoundMode: azanSoundMode, customSoundUri: customSoundUri);

    await _plugin.show(
      id: 900001,
      title: _testTitle(langCode),
      body: _testBody(langCode),
      notificationDetails: _buildNotifDetails(
          soundOn: soundOn, azanSoundMode: azanSoundMode,
          customSoundUri: customSoundUri, channelId: channelId, channelName: channelName),
    );
  }

  // ─── Channel resolution ──────────────────────────────────────────────────

  static NotificationDetails _buildNotifDetails({
    required bool soundOn,
    required String azanSoundMode,
    required String? customSoundUri,
    required String channelId,
    required String channelName,
  }) {
    final AndroidNotificationSound? androidSound;
    final String? iosSound;

    if (!soundOn) {
      androidSound = null; iosSound = null;
    } else if (azanSoundMode == AppSettings.azanSoundModeDefaultAzan) {
      androidSound = const RawResourceAndroidNotificationSound('azan');
      iosSound = 'azan.mp3';
    } else if (azanSoundMode == AppSettings.azanSoundModeCustom && customSoundUri != null) {
      androidSound = UriAndroidNotificationSound(customSoundUri);
      iosSound = null;
    } else {
      androidSound = null; iosSound = null;
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: 'Reminders for each prayer time',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat_namaztime',
        playSound: soundOn,
        sound: androidSound,
      ),
      iOS: DarwinNotificationDetails(presentSound: soundOn, sound: iosSound),
    );
  }

  static String _resolveChannelName(bool soundOn, String azanSoundMode) {
    if (!soundOn) return 'Prayer Times (Silent)';
    if (azanSoundMode == AppSettings.azanSoundModeDefaultAzan) return 'Prayer Times (Azan)';
    return 'Prayer Times';
  }

  static String _resolveChannelId({
    required bool soundOn,
    required String azanSoundMode,
    required String? customSoundUri,
  }) {
    if (!soundOn) return _channelSilent;
    if (azanSoundMode == AppSettings.azanSoundModeDefaultAzan) return _channelDefaultAzan;
    if (azanSoundMode == AppSettings.azanSoundModeCustom &&
        customSoundUri != null && customSoundUri.isNotEmpty) {
      final hash = base64Url.encode(utf8.encode(customSoundUri)).replaceAll('=', '');
      return 'prayer_times_sound_$hash';
    }
    return _channelSound;
  }

  static Future<void> _ensureDynamicChannel({
    required String channelId,
    required String channelName,
    required bool soundOn,
    required String azanSoundMode,
    required String? customSoundUri,
  }) async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    final AndroidNotificationSound? sound;
    if (!soundOn) {
      sound = null;
    } else if (azanSoundMode == AppSettings.azanSoundModeDefaultAzan) {
      sound = const RawResourceAndroidNotificationSound('azan');
    } else if (azanSoundMode == AppSettings.azanSoundModeCustom && customSoundUri != null) {
      sound = UriAndroidNotificationSound(customSoundUri);
    } else {
      sound = null;
    }

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelId, channelName,
        description: 'Reminders for each prayer time',
        importance: Importance.high,
        playSound: soundOn,
        sound: sound,
        enableVibration: true,
      ),
    );
  }

  // ─── Notification text ───────────────────────────────────────────────────

  static String _prayerTitle(String key, String lang) {
    const names = {
      'ru': {'fajr': 'Фаджр', 'dhuhr': 'Зухр', 'asr': 'Аср', 'maghrib': 'Магриб', 'isha': 'Иша'},
      'ky': {'fajr': 'Бамдат', 'dhuhr': 'Бешим', 'asr': 'Асыр', 'maghrib': 'Шам', 'isha': 'Куптан'},
      'en': {'fajr': 'Fajr', 'dhuhr': 'Dhuhr', 'asr': 'Asr', 'maghrib': 'Maghrib', 'isha': 'Isha'},
    };
    return names[lang]?[key] ?? key;
  }

  // Normal bodies
  static String _prayerBody(String key, String time, int before, String lang) {
    final name = _prayerTitle(key, lang);
    switch (lang) {
      case 'ky': return '$name намазы $time да башталат ($before мин. калды)';
      case 'en': return '$name prayer at $time (in $before min)';
      default:   return 'Намаз $name в $time (через $before мин)';
    }
  }

  static String _azanNowBody(String key, String time, String lang) {
    final name = _prayerTitle(key, lang);
    switch (lang) {
      case 'ky': return '$name намазынын убактысы болду ($time)';
      case 'en': return 'It is time for $name prayer ($time)';
      default:   return 'Наступило время намаза $name ($time)';
    }
  }

  // Stale-data bodies — include the source date and ask the user to open app
  static String _prayerBodyStale(
      String key, String time, int before, String lang, String dateLabel) {
    final name = _prayerTitle(key, lang);
    switch (lang) {
      case 'ky':
        return '$name $time да ($dateLabel маалыматы) — так убакытты алуу үчүн тиркемени ачыңыз';
      case 'en':
        return '$name at $time · data from $dateLabel — open app for accurate time';
      default:
        return '$name в $time · данные от $dateLabel — откройте приложение для точного времени';
    }
  }

  static String _azanNowBodyStale(
      String key, String time, String lang, String dateLabel) {
    final name = _prayerTitle(key, lang);
    switch (lang) {
      case 'ky':
        return '$name $time ($dateLabel маалыматы) — тиркемени ачыңыз';
      case 'en':
        return '$name $time · data from $dateLabel — open app to update';
      default:
        return '$name $time · данные от $dateLabel — откройте приложение';
    }
  }

  static String _testTitle(String lang) {
    switch (lang) {
      case 'ky': return 'Азан үнүн текшерүү';
      case 'en': return 'Azan sound test';
      default:   return 'Тест звука азана';
    }
  }

  static String _testBody(String lang) {
    switch (lang) {
      case 'ky': return 'Азыркы тандалган рингтон текшерилүүдө';
      case 'en': return 'Testing your currently selected ringtone';
      default:   return 'Проверка текущего выбранного рингтона';
    }
  }

  // ─── Date helpers ────────────────────────────────────────────────────────

  /// Human-readable date label for stale notifications, e.g. "15 мая" / "15 May".
  static String _formatDateForNotif(String dateStr, String lang) {
    DateTime? dt;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
      dt = DateTime.tryParse(dateStr);
    } else if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(dateStr)) {
      final p = dateStr.split('-');
      dt = DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
    }
    if (dt == null) return dateStr;

    const monthsRu = ['янв', 'фев', 'мар', 'апр', 'май', 'июн',
                      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final months = lang == 'en' ? monthsEn : monthsRu;
    return '${dt.day} ${months[dt.month - 1]}';
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

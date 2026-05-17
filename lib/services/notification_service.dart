import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  // NOTE: _channelDefaultAzan is versioned because Android locks channel sound
  // settings after first creation — changing the ID forces a fresh channel with
  // the correct azan sound.
  static const _channelSound       = 'prayer_times_sound';
  static const _channelSilent      = 'prayer_times_silent';
  static const _channelDefaultAzan = 'prayer_times_azan_v3';

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

    // flutter_local_notifications validates the init icon via getIdentifier() at
    // startup — it checks "mipmap" first, then "drawable". @mipmap/ic_launcher
    // is guaranteed to exist in every Flutter APK and never throws invalid_icon.
    // The per-notification icon (@drawable/ic_stat_namaztime) is set separately
    // in AndroidNotificationDetails and is resolved lazily when the notification
    // fires, so it works correctly from the density-specific PNG files.
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
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

  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      final granted = await android?.requestNotificationsPermission();
      if (granted != null) return granted;
    } catch (e) {
      debugPrint('NotificationService: request permission failed — $e');
    }
    return true;
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

    final wantedChannelId   = _resolveChannelId(
        soundOn: soundOn, azanSoundMode: azanSoundMode, customSoundUri: customSoundUri);
    final wantedChannelName = _resolveChannelName(soundOn, azanSoundMode);
    final actualChannelId   = await _ensureDynamicChannel(
        channelId: wantedChannelId, channelName: wantedChannelName,
        soundOn: soundOn, azanSoundMode: azanSoundMode, customSoundUri: customSoundUri);
    final effectiveAzanMode = actualChannelId == wantedChannelId ? azanSoundMode : '';
    final actualChannelName = _resolveChannelName(soundOn, effectiveAzanMode);

    final details = _buildNotifDetails(
        soundOn: soundOn, azanSoundMode: effectiveAzanMode,
        customSoundUri: customSoundUri, channelId: actualChannelId, channelName: actualChannelName);

    final dateLabel = stale ? _formatDateForNotif(staleDate ?? times.date, langCode) : null;
    final prayers   = times.prayers;

    for (int i = 0; i < prayers.length; i++) {
      final prayer = prayers[i];
      // Sunrise is an orientation marker only — never send a notification for it.
      if (prayer.isInformational) continue;
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
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  /// Fetch tomorrow's times and schedule them into the "tomorrow" ID range
  /// without touching today's already-scheduled notifications.
  ///
  /// Falls back to today's cached prayer times when the network is unavailable,
  /// so Fajr (the first prayer) is always guaranteed a notification even when
  /// the device is offline or WorkManager is restricted by battery optimisation.
  static void _prescheduleTomorrow(String langCode) {
    () async {
      try {
        final rawLoc = AppSettings.savedLocationJson;
        if (rawLoc == null) return;

        final location = AppLocation.fromJson(rawLoc);
        final repo     = PrayerTimesRepository();
        final tomorrow = _dateOnly(DateTime.now()).add(const Duration(days: 1));

        DailyPrayerTimes? tomorrowTimes;

        // Try to fetch tomorrow's exact times from the network.
        try {
          tomorrowTimes = await repo.fetchForLocation(location, date: tomorrow);
        } catch (e) {
          debugPrint('NotificationService: tomorrow fetch failed, trying cache — $e');
          // Network unavailable — use today's cached times as a close approximation
          // (prayer times shift by only ~1–2 min per day, so this is safe).
          final cachedJson = AppSettings.cachedPrayerTimesJson;
          if (cachedJson != null) {
            tomorrowTimes = DailyPrayerTimes.fromCacheJson(cachedJson);
          }
        }

        if (tomorrowTimes == null) return;

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

  static Future<bool> showTestNotification(String langCode) async {
    await init();
    final granted = await requestPermission();
    if (!granted) return false;

    final soundOn        = AppSettings.soundEnabled;
    final azanSoundMode  = AppSettings.azanSoundMode;
    final customSoundUri = AppSettings.customSoundUri;
    final wantedChannelId   = _resolveChannelId(
        soundOn: soundOn, azanSoundMode: azanSoundMode, customSoundUri: customSoundUri);
    final wantedChannelName = _resolveChannelName(soundOn, azanSoundMode);
    try {
      // _ensureDynamicChannel returns the channel actually created — may differ
      // from the requested one when the azan raw resource is missing from the APK.
      final actualChannelId = await _ensureDynamicChannel(
          channelId: wantedChannelId, channelName: wantedChannelName,
          soundOn: soundOn, azanSoundMode: azanSoundMode, customSoundUri: customSoundUri);
      final actualChannelName = _resolveChannelName(soundOn,
          actualChannelId == wantedChannelId ? azanSoundMode : '');

      await _plugin.show(
        id: 900001,
        title: _testTitle(langCode),
        body: _testBody(langCode),
        notificationDetails: _buildNotifDetails(
            soundOn: soundOn,
            azanSoundMode: actualChannelId == wantedChannelId ? azanSoundMode : '',
            customSoundUri: customSoundUri,
            channelId: actualChannelId,
            channelName: actualChannelName),
      );
      return true;
    } catch (e) {
      debugPrint('NotificationService: test notification failed — $e');
      return false;
    }
  }

  // ─── Channel resolution ──────────────────────────────────────────────────

  static NotificationDetails _buildNotifDetails({
    required bool soundOn,
    required String azanSoundMode,
    required String? customSoundUri,
    required String channelId,
    required String channelName,
  }) {
    // iOS still needs an explicit sound reference.
    final String? iosSound;
    if (!soundOn) {
      iosSound = null;
    } else if (azanSoundMode == AppSettings.azanSoundModeDefaultAzan) {
      iosSound = 'azan.mp3';
    } else {
      iosSound = null;
    }

    // Android 8.0+: sound is controlled entirely by the channel — specifying
    // `sound` here causes a redundant getIdentifier() call that throws
    // invalid_sound when the raw resource is missing from the APK. Omit it.
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: 'Reminders for each prayer time',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        playSound: soundOn,
        // sound: omitted — channel sound takes precedence on Android 8+
        enableVibration: true,
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

  /// Creates (or verifies) the notification channel for [channelId].
  /// Returns the channel ID actually used — falls back to [_channelSound] when
  /// the azan raw resource is missing from the APK (stale Gradle cache).
  /// This avoids permanently poisoning [_channelDefaultAzan] with no sound,
  /// which would happen if we created it without the sound resource.
  static Future<String> _ensureDynamicChannel({
    required String channelId,
    required String channelName,
    required bool soundOn,
    required String azanSoundMode,
    required String? customSoundUri,
  }) async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return channelId;

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

    try {
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
      return channelId;
    } on PlatformException catch (e) {
      if (e.code == 'invalid_sound') {
        // azan.mp3 is not yet compiled into the APK (stale Gradle cache).
        // Do NOT create the azan channel without sound — it would be locked
        // permanently silent. Fall back to the standard sound channel so at
        // least the notification appears. After running:
        //   flutter clean && cd android && ./gradlew clean && cd .. && flutter run
        // the azan channel will be created correctly on next launch.
        debugPrint(
          'NotificationService: azan.mp3 missing from APK — falling back to '
          'default sound.\nFix: flutter clean && cd android && ./gradlew clean '
          '&& cd .. && flutter run',
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelSound,
            'Prayer Times',
            description: 'Reminders for each prayer time',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
        return _channelSound; // tell the caller to use this fallback channel
      }
      rethrow;
    }
  }

  // ─── Notification text ───────────────────────────────────────────────────

  static String _prayerTitle(String key, String lang) {
    const names = {
      'ru': {'fajr': 'Фаджр', 'dhuhr': 'Зухр', 'asr': 'Аср', 'maghrib': 'Магриб', 'isha': 'Иша'},
      'ky': {'fajr': 'Багымдат', 'dhuhr': 'Бешим', 'asr': 'Аср', 'maghrib': 'Шам', 'isha': 'Куптан'},
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

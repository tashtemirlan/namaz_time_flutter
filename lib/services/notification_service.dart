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

  // Two channels: one with sound, one silent.
  // Android 8+ ties sound to the channel — we create both upfront
  // and pick the right one at schedule time.
  static const _channelSound  = 'prayer_times_sound';
  static const _channelSilent = 'prayer_times_silent';

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    _setLocalTimezone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings: settings);

    // Pre-create both Android channels so the user can manage them
    // in system settings independently.
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
      debugPrint('NotificationService: timezone init error: \$e');
    }
  }

  static Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Schedule notifications for all enabled prayers today.
  static Future<void> schedulePrayerNotifications(
    DailyPrayerTimes times,
    String langCode,
  ) async {
    await cancelAll();
    final beforeMin  = AppSettings.notifyBeforeMinutes;
    final soundOn    = AppSettings.soundEnabled;
    final customSoundUri = AppSettings.customSoundUri;
    final now        = DateTime.now();

    final channelId = _resolveChannelId(
      soundOn: soundOn,
      customSoundUri: customSoundUri,
    );
    final channelName = soundOn ? 'Prayer Times' : 'Prayer Times (Silent)';
    await _ensureDynamicChannel(
      channelId: channelId,
      channelName: channelName,
      soundOn: soundOn,
      customSoundUri: customSoundUri,
    );

    final prayers = times.prayers;
    for (int i = 0; i < prayers.length; i++) {
      final prayer = prayers[i];
      if (!AppSettings.isPrayerNotifEnabled(prayer.key)) continue;

      final dt = prayer.toDateTime();
      if (dt == null) continue;

      // 1) Reminder before azan time (if enabled and still in future)
      if (beforeMin > 0) {
        final notifTime = dt.subtract(Duration(minutes: beforeMin));
        if (!notifTime.isBefore(now)) {
          await _plugin.zonedSchedule(
            id: i,
            title: _prayerTitle(prayer.key, langCode),
            body: _prayerBody(prayer.key, prayer.time, beforeMin, langCode),
            scheduledDate: tz.TZDateTime.from(notifTime, tz.local),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channelId,
                channelName,
                channelDescription: 'Reminders for each prayer time',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
                playSound: soundOn,
                sound: soundOn && customSoundUri != null
                    ? UriAndroidNotificationSound(customSoundUri)
                    : null,
              ),
              iOS: DarwinNotificationDetails(
                presentSound: soundOn,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }

      // 2) Exact azan-time notification
      if (!dt.isBefore(now)) {
        await _plugin.zonedSchedule(
          id: 1000 + i,
          title: _prayerTitle(prayer.key, langCode),
          body: _azanNowBody(prayer.key, prayer.time, langCode),
          scheduledDate: tz.TZDateTime.from(dt, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              channelDescription: 'Reminders for each prayer time',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: soundOn,
              sound: soundOn && customSoundUri != null
                  ? UriAndroidNotificationSound(customSoundUri)
                  : null,
            ),
            iOS: DarwinNotificationDetails(
              presentSound: soundOn,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  /// Start automatic daily refresh: at local 00:00 fetch prayer times and
  /// schedule all notifications for the new day.
  static void startDailyAutoRefresh() {
    _midnightTimer?.cancel();
    _scheduleNextMidnightTick();
  }

  static void _scheduleNextMidnightTick() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);

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

  /// Fetch today's times for saved location and re-schedule all notifications.
  static Future<void> refreshScheduleForToday() async {
    final rawLoc = AppSettings.savedLocationJson;
    if (rawLoc == null) return;
    final location = AppLocation.fromJson(rawLoc);
    final repo = PrayerTimesRepository();
    final times = await repo.fetchForLocation(location);
    await schedulePrayerNotifications(times, AppSettings.language);
  }

  static String _resolveChannelId({
    required bool soundOn,
    required String? customSoundUri,
  }) {
    if (!soundOn) return _channelSilent;
    if (customSoundUri == null || customSoundUri.isEmpty) return _channelSound;
    final hash = base64Url.encode(utf8.encode(customSoundUri)).replaceAll('=', '');
    return 'prayer_times_sound_$hash';
  }

  static Future<void> _ensureDynamicChannel({
    required String channelId,
    required String channelName,
    required bool soundOn,
    required String? customSoundUri,
  }) async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Reminders for each prayer time',
        importance: Importance.high,
        playSound: soundOn,
        sound: soundOn && customSoundUri != null
            ? UriAndroidNotificationSound(customSoundUri)
            : null,
        enableVibration: true,
      ),
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Show an immediate test notification using current sound settings.
  static Future<void> showTestNotification(String langCode) async {
    final soundOn = AppSettings.soundEnabled;
    final customSoundUri = AppSettings.customSoundUri;
    final channelId = _resolveChannelId(
      soundOn: soundOn,
      customSoundUri: customSoundUri,
    );
    final channelName = soundOn ? 'Prayer Times' : 'Prayer Times (Silent)';
    await _ensureDynamicChannel(
      channelId: channelId,
      channelName: channelName,
      soundOn: soundOn,
      customSoundUri: customSoundUri,
    );

    await _plugin.show(
      id: 900001,
      title: _testTitle(langCode),
      body: _testBody(langCode),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Test reminder notification',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: soundOn,
          sound: soundOn && customSoundUri != null
              ? UriAndroidNotificationSound(customSoundUri)
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: soundOn,
        ),
      ),
    );
  }

  static String _prayerTitle(String key, String lang) {
    const names = {
      'ru': {'fajr': 'Фажр', 'dhuhr': 'Дуур', 'asr': 'Асыр', 'maghrib': 'Магриб', 'isha': 'Ишаа'},
      'ky': {'fajr': 'Бамдат', 'dhuhr': 'Бешим', 'asr': 'Асыр', 'maghrib': 'Шам', 'isha': 'Куптан'},
      'en': {'fajr': 'Fajr', 'dhuhr': 'Dhuhr', 'asr': 'Asr', 'maghrib': 'Maghrib', 'isha': 'Isha'},
    };
    return names[lang]?[key] ?? key;
  }

  static String _prayerBody(String key, String time, int before, String lang) {
    final name = _prayerTitle(key, lang);
    switch (lang) {
      case 'ky': return '$name намазы $time да башталат ($before мин. калды)';
      case 'en': return '$name prayer at $time (in $before min)';
      default:   return 'Намаз $name в $time (через $before мин)';
    }
  }

  static String _testTitle(String lang) {
    switch (lang) {
      case 'ky': return 'Азан үнүн текшерүү';
      case 'en': return 'Azan sound test';
      default: return 'Тест звука азана';
    }
  }

  static String _testBody(String lang) {
    switch (lang) {
      case 'ky': return 'Азыркы тандалган рингтон текшерилүүдө';
      case 'en': return 'Testing your currently selected ringtone';
      default: return 'Проверка текущего выбранного рингтона';
    }
  }

  static String _azanNowBody(String key, String time, String lang) {
    final name = _prayerTitle(key, lang);
    switch (lang) {
      case 'ky': return '$name намазынын убактысы болду ($time)';
      case 'en': return 'It is time for $name prayer ($time)';
      default: return 'Наступило время намаза $name ($time)';
    }
  }
}

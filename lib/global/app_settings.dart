import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persisted app-level settings backed by Hive.
class AppSettings {
  AppSettings._();

  static const _boxName = 'app_settings';
  static const _themeKey = 'theme';
  static const _langKey = 'lang';
  static const _locationKey = 'location';
  static const _notifPrefix = 'notif_';
  static const _notifBeforeKey = 'notif_before_min';

  static late Box _box;

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    final saved = _box.get(_themeKey, defaultValue: 'system') as String;
    themeMode.value = _themeFromString(saved);
  }

  // ─── Theme ────────────────────────────────────────────────────────────────
  static void toggleTheme() {
    final next = themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setTheme(next);
  }

  static void setTheme(ThemeMode mode) {
    themeMode.value = mode;
    _box.put(_themeKey, _themeToString(mode));
  }

  static ThemeMode _themeFromString(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system;
    }
  }

  static String _themeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return 'light';
      case ThemeMode.dark:   return 'dark';
      default:               return 'system';
    }
  }

  // ─── Language ─────────────────────────────────────────────────────────────
  static String get language =>
      _box.get(_langKey, defaultValue: 'ru') as String;

  static Future<void> setLanguage(String code) =>
      _box.put(_langKey, code);

  // ─── Location (raw JSON) ─────────────────────────────────────────────────
  static Map<String, dynamic>? get savedLocationJson {
    final raw = _box.get(_locationKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  static Future<void> saveLocationJson(Map<String, dynamic> json) =>
      _box.put(_locationKey, json);

  // ─── Per-prayer notification flags ───────────────────────────────────────
  static bool isPrayerNotifEnabled(String prayerKey) =>
      _box.get('$_notifPrefix$prayerKey', defaultValue: true) as bool;

  static Future<void> setPrayerNotif(String prayerKey, bool enabled) =>
      _box.put('$_notifPrefix$prayerKey', enabled);

  static int get notifyBeforeMinutes =>
      _box.get(_notifBeforeKey, defaultValue: 10) as int;

  static Future<void> setNotifyBeforeMinutes(int min) =>
      _box.put(_notifBeforeKey, min);

  // ─── Notification sound ───────────────────────────────────────────────────
  static const _soundEnabledKey = 'sound_enabled';
  static const _soundUriKey = 'sound_uri';
  static const _lastBgRefreshDateKey = 'bg_last_refresh_date';

  static bool get soundEnabled =>
      _box.get(_soundEnabledKey, defaultValue: true) as bool;

  static Future<void> setSoundEnabled(bool enabled) =>
      _box.put(_soundEnabledKey, enabled);

  static String? get customSoundUri =>
      (() {
        final value = (_box.get(_soundUriKey) as String?)?.trim();
        return (value == null || value.isEmpty) ? null : value;
      })();

  static Future<void> setCustomSoundUri(String? uri) async {
    final value = uri?.trim();
    if (value == null || value.isEmpty) {
      await _box.delete(_soundUriKey);
      return;
    }
    await _box.put(_soundUriKey, value);
  }

  // ─── Background refresh marker ────────────────────────────────────────────
  static String? get lastBgRefreshDate =>
      (_box.get(_lastBgRefreshDateKey) as String?)?.trim();

  static Future<void> setLastBgRefreshDate(String value) =>
      _box.put(_lastBgRefreshDateKey, value);
}

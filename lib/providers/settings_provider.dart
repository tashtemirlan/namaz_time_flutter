import 'package:flutter/foundation.dart';
import '../global/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  static const _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  final Map<String, bool> _notifEnabled = {};
  int _notifBeforeMin = 10;
  bool _soundEnabled = true;
  String? _customSoundUri;

  Map<String, bool> get notifEnabled => Map.unmodifiable(_notifEnabled);
  int get notifBeforeMin => _notifBeforeMin;
  bool get soundEnabled => _soundEnabled;
  String? get customSoundUri => _customSoundUri;

  SettingsProvider() {
    _load();
  }

  void _load() {
    _notifBeforeMin = AppSettings.notifyBeforeMinutes;
    _soundEnabled = AppSettings.soundEnabled;
    _customSoundUri = AppSettings.customSoundUri;
    for (final p in _prayers) {
      _notifEnabled[p] = AppSettings.isPrayerNotifEnabled(p);
    }
  }

  Future<void> setNotifEnabled(String prayer, bool enabled) async {
    _notifEnabled[prayer] = enabled;
    await AppSettings.setPrayerNotif(prayer, enabled);
    notifyListeners();
  }

  Future<void> setNotifBeforeMin(int min) async {
    _notifBeforeMin = min;
    await AppSettings.setNotifyBeforeMinutes(min);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await AppSettings.setSoundEnabled(enabled);
    notifyListeners();
  }

  Future<void> setCustomSoundUri(String? uri) async {
    _customSoundUri = uri;
    await AppSettings.setCustomSoundUri(uri);
    notifyListeners();
  }

  bool isEnabled(String prayer) => _notifEnabled[prayer] ?? true;
}

<div align="center">

# 🕌 NamazTime

**Accurate prayer times, Qibla compass, and azan notifications — built for Kyrgyzstan and the world.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey)](https://github.com)
[![License](https://img.shields.io/badge/License-MIT-green)](#license)

</div>

---

## ✨ Features

| Feature | Description |
|---|---|
| 🕐 **Prayer Times** | Daily Fajr, Sunrise, Dhuhr, Asr, Maghrib & Isha with live countdown |
| 🧭 **Qibla Compass** | Real-time compass bearing to Mecca using the device sensor |
| 🔔 **Azan Notifications** | Scheduled local notifications with custom ringtone support |
| 🌍 **Global Coverage** | Kyrgyzstan via Muftiyat KR API · 13 other countries via AlAdhan |
| 🌙 **Hijri Calendar** | Current Islamic date displayed on the home screen |
| 🌗 **Dark / Light Theme** | "Lemongrass & Parchment" design system, toggled per user preference |
| 🌐 **3 Languages** | Русский · Кыргызча · English (easy_localization) |
| 📍 **Location Picker** | 130+ Kyrgyzstan cities (muftiyat codes) + worldwide GPS fallback |

---

## 📸 Screenshots

> _Coming soon — run the app locally to see it in action._

---

## 🏗️ Architecture

```
lib/
├── data/            # Static location datasets (kg_locations, world_locations)
├── global/          # AppSettings — Hive-persisted theme, language, prefs
├── models/          # DailyPrayerTimes, PrayerEntry, AppLocation, HijriDate
├── providers/       # LocationProvider, PrayerProvider (countdown), SettingsProvider
├── repositories/    # PrayerTimesRepository — dispatches to muftiyat.kg or AlAdhan
├── services/        # NotificationService, QiblaService, BackgroundRefreshService
└── ui/
    ├── navigation/  # AppBottomNavBar
    ├── screens/     # Home, Qibla, LocationPicker, Settings
    ├── theme/       # AppColors, AppTheme, AppExtensions
    └── widgets/     # AppText, AppButton, AppTextField, AppSnackBar
```

**State management:** Provider  
**Storage:** Hive (theme, language, location, notification prefs)  
**HTTP:** Dio

---

### Build

```bash
make build-apk          # Android APK (release)
make build-aab          # Android App Bundle (Play Store)
make build-ios          # iOS IPA
```

---

## 🛠️ Developer Commands

```bash
make help               # Full list of all available targets
make run                # Debug run on the default device
make analyze            # Flutter static analysis
make format             # Auto-format lib/ with dart format
make test               # Run all tests
make generate-icons     # Regenerate launcher icons from assets/icon.png
make generate-locales   # Validate all translation JSON files
make translations-diff  # Check key parity across ru / ky / en
make clean              # Remove build artifacts
make clean-hive         # Clear Hive app data on Android emulator
```

---

## 🌐 Localization

Translations live in `assets/translations/{lang}.json`.

| Code | Language | Status |
|---|---|---|
| `ru` | Русский | ✅ Primary / fallback |
| `ky` | Кыргызча | ✅ Full |
| `en` | English | ✅ Full |

Run `make translations-diff` to catch any missing or extra keys.

---

## 📄 License

This project is licensed under the MIT License.

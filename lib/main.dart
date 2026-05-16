import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'global/app_settings.dart';
import 'providers/location_provider.dart';
import 'providers/prayer_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/prayer_times_repository.dart';
import 'services/notification_service.dart';
import 'services/background_refresh_service.dart';
import 'ui/navigation/app_bottom_nav_bar.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive
  await Hive.initFlutter();

  // App settings (theme, language, location, notification prefs)
  await AppSettings.init();

  // Easy localization
  await EasyLocalization.ensureInitialized();

  // Notifications
  await NotificationService.init();
  await NotificationService.requestPermission();
  await NotificationService.refreshScheduleForToday();
  NotificationService.startDailyAutoRefresh();
  await BackgroundRefreshService.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('ky'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ru'),
      startLocale: Locale(AppSettings.language),
      child: const NamazTimeApp(),
    ),
  );
}

class NamazTimeApp extends StatelessWidget {
  const NamazTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(
          create: (_) => PrayerProvider(PrayerTimesRepository()),
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppSettings.themeMode,
        builder: (_, themeMode, __) {
          return MaterialApp(
            title: 'Намаз убактысы',
            debugShowCheckedModeBanner: false,
            theme:      AppTheme.light,
            darkTheme:  AppTheme.dark,
            themeMode:  themeMode,
            locale:              context.locale,
            supportedLocales:    context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const DefaultTabController(
              length: 4,
              child: AppBottomNavBar(),
            ),
          );
        },
      ),
    );
  }
}

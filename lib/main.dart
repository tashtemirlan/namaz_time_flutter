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
import 'ui/screens/splash/splash_screen.dart';
import 'ui/theme/app_theme.dart';

/// App name constants — change here once, reflects everywhere.
const String kAppName   = 'NamazTime';
const String kAppNameKy = 'Намаз убактысы';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Fast, local-only init ──────────────────────────────────────────────────
  // Only work that MUST complete before the first frame goes here.
  // Network calls and WorkManager setup are deferred to SplashScreen so the
  // user sees the app UI immediately instead of a white screen.

  await Hive.initFlutter();
  await AppSettings.init();
  await EasyLocalization.ensureInitialized();

  // Notification plugin must be initialised before any permission dialog.
  await NotificationService.init();
  await NotificationService.requestPermission();

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
            title: kAppName,
            debugShowCheckedModeBanner: false,
            theme:      AppTheme.light,
            darkTheme:  AppTheme.dark,
            themeMode:  themeMode,
            locale:              context.locale,
            supportedLocales:    context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            // SplashScreen runs heavy init (network, WorkManager) and then
            // replaces itself with AppBottomNavBar via pushReplacement.
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';
import '../global/app_settings.dart';
import 'notification_service.dart';

const String kDailyRefreshTask = 'daily_prayer_refresh_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await AppSettings.init();
      await NotificationService.init();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (AppSettings.lastBgRefreshDate == today) {
        return Future.value(true);
      }

      await NotificationService.refreshScheduleForToday();
      await AppSettings.setLastBgRefreshDate(today);
      return Future.value(true);
    } catch (_) {
      return Future.value(false);
    }
  });
}

class BackgroundRefreshService {
  BackgroundRefreshService._();

  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().registerPeriodicTask(
      'daily-prayer-refresh',
      kDailyRefreshTask,
      frequency: const Duration(hours: 6),
      initialDelay: const Duration(minutes: 10),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.update,
    );
  }
}

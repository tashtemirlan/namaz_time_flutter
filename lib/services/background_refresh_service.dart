import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';
import '../global/app_settings.dart';
import 'notification_service.dart';

const String kDailyRefreshTask    = 'daily_prayer_refresh_task';
const String kMidnightRefreshTask = 'midnight_prayer_refresh_task';

/// Background entry-point executed by WorkManager in a separate isolate.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    bool success = false;
    try {
      await AppSettings.init();
      await NotificationService.init();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (AppSettings.lastBgRefreshDate != today) {
        // Fetch fresh data (or fall back to cache) and reschedule notifications.
        await NotificationService.refreshScheduleForToday();
        await AppSettings.setLastBgRefreshDate(today);
      }
      success = true;
    } catch (e) {
      debugPrint('callbackDispatcher: task failed — $e');
      success = false;
    }

    // ── Self-reschedule the midnight task regardless of success ──────────
    // This keeps the chain alive as long as WorkManager is allowed to run,
    // even if the app is killed and never reopened.
    try {
      await BackgroundRefreshService.scheduleNextMidnightTask();
    } catch (e) {
      debugPrint('callbackDispatcher: midnight reschedule failed — $e');
    }

    return Future.value(success);
  });
}

class BackgroundRefreshService {
  BackgroundRefreshService._();

  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // ── Periodic fallback (every 6 h) ────────────────────────────────────
    // Catches any day where the midnight one-off task was missed or delayed.
    // networkType: not_required — we handle offline fallback ourselves.
    await Workmanager().registerPeriodicTask(
      'daily-prayer-refresh',
      kDailyRefreshTask,
      frequency: const Duration(hours: 6),
      initialDelay: const Duration(minutes: 10),
      constraints: Constraints(networkType: NetworkType.not_required),
      existingWorkPolicy: ExistingWorkPolicy.update,
    );

    // ── Precise midnight one-off task ────────────────────────────────────
    // Fires close to 00:00 local time; self-reschedules on each execution.
    await scheduleNextMidnightTask();
  }

  /// Schedule a one-off WorkManager task to fire at the next local midnight.
  ///
  /// Called from [init] AND from [callbackDispatcher] so the chain is
  /// always extended — even when the app is totally killed for weeks.
  static Future<void> scheduleNextMidnightTask() async {
    final now          = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay        = nextMidnight.difference(now);

    await Workmanager().registerOneOffTask(
      kMidnightRefreshTask,   // unique name — replaces any existing one
      kMidnightRefreshTask,
      initialDelay: delay,
      // No network constraint — offline cache handles no-network gracefully.
      constraints: Constraints(networkType: NetworkType.not_required),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}

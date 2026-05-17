import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/background_refresh_service.dart';
import '../../../services/notification_service.dart';
// ignore_for_file: use_build_context_synchronously
import '../../navigation/app_bottom_nav_bar.dart';

/// Shows while the app performs its heavy first-launch initialization
/// (fetching prayer times, scheduling notifications, starting WorkManager).
/// Replaces itself with [AppBottomNavBar] once everything is ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();

    // Defer heavy initialization until after the first frame renders so the
    // user immediately sees the splash instead of a white screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final startTime = DateTime.now();

    try {
      // 1. Init the notification plugin and ask for permission.
      //    Moved here from main() so runApp() has zero network/plugin awaits.
      await NotificationService.init();
      await NotificationService.requestPermission();

      // 2. Fetch today's prayer times and schedule all notifications.
      await NotificationService.refreshScheduleForToday();
      NotificationService.startDailyAutoRefresh();

      // 3. Start WorkManager for background midnight refresh.
      await BackgroundRefreshService.init();
    } catch (e) {
      debugPrint('SplashScreen: init error — $e');
      // Non-fatal: continue to the app even if init partially fails.
    }

    // Ensure the splash is visible for at least 800 ms so it doesn't flash.
    final elapsed = DateTime.now().difference(startTime);
    const minDisplay = Duration(milliseconds: 800);
    if (elapsed < minDisplay) {
      await Future.delayed(minDisplay - elapsed);
    }

    if (!mounted) return;
    _navigateToMain();
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DefaultTabController(
          length: 4,
          child: AppBottomNavBar(),
        ),
        transitionDuration: const Duration(milliseconds: 450),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use fixed brand colors — theme extension may not be needed here.
    const deepGreen = Color(0xFF1B3D2A);
    const midGreen = Color(0xFF2E6645);

    return Scaffold(
      backgroundColor: deepGreen,
      body: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Stack(
            children: [
              // Decorative background
              Positioned.fill(
                child: CustomPaint(painter: _SplashDecorPainter()),
              ),
              // Content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mosque icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Text('🕌', style: TextStyle(fontSize: 52)),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // App name
                    const Text(
                      'NamazTime',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Tagline — native name
                    Text(
                      'Намаз убактысы',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.60),
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 56),

                    // Subtle loading indicator
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Decorative background ────────────────────────────────────────────────

class _SplashDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Large crescent (top-right)
    final moonCenter = Offset(size.width + 20, -20);
    canvas.drawCircle(moonCenter, 140, paint);
    final maskPaint = Paint()
      ..color = const Color(0xFF1B3D2A).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width + 52, 22), 119, maskPaint);

    // Dot grid
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }

    // Stars
    _drawStar(canvas, Offset(size.width * 0.15, size.height * 0.12), 8, paint..strokeWidth = 1.0);
    _drawStar(canvas, Offset(size.width * 0.25, size.height * 0.07), 5, paint..strokeWidth = 0.8);
    _drawStar(canvas, Offset(size.width * 0.78, size.height * 0.82), 6, paint..strokeWidth = 0.9);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 6;
      final outer = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      final inner = Offset(
        center.dx + r * 0.45 * math.cos(angle + math.pi / 6),
        center.dy + r * 0.45 * math.sin(angle + math.pi / 6),
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SplashDecorPainter old) => false;
}

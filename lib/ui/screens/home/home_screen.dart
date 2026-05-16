import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/prayer_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../models/prayer_time_model.dart';
import '../../../services/notification_service.dart';
import '../../../global/app_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_extensions.dart';
import '../../widgets/app/app_text.dart';
import '../../widgets/app/app_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final loc = context.read<LocationProvider>().location;
    if (loc == null) return;
    final prayer = context.read<PrayerProvider>();
    await prayer.load(loc);

    if (!mounted) return;
    final times = prayer.times;
    if (times != null) {
      await NotificationService.schedulePrayerNotifications(
          times, AppSettings.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final location = context.watch<LocationProvider>().location;
    final prayer = context.watch<PrayerProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Hero header — gradient with live clock
            SliverToBoxAdapter(
              child: _HeroHeader(
                cityName: location?.cityName,
                colors: colors,
              ),
            ),

            if (location == null)
              SliverFillRemaining(
                child: _NoLocationPlaceholder(onTap: _goToLocation),
              )
            else if (prayer.state == PrayerLoadState.loading)
              SliverFillRemaining(child: _LoadingView(colors: colors))
            else if (prayer.state == PrayerLoadState.error)
              SliverFillRemaining(
                child: _ErrorView(
                  message: prayer.errorMessage ?? 'home.error'.tr(),
                  onRetry: _load,
                  colors: colors,
                ),
              )
            else if (prayer.state == PrayerLoadState.loaded &&
                prayer.times != null) ...[
              // Next prayer banner
              SliverToBoxAdapter(
                child: _NextPrayerBanner(prayer: prayer, colors: colors),
              ),
              // Section title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [colors.primary, colors.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppText(
                        text: 'home.prayer_times'.tr(),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'PlayfairDisplay',
                        color: colors.text,
                      ),
                    ],
                  ),
                ),
              ),
              // Prayer cards
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final p = prayer.times!.prayers[i];
                    return RepaintBoundary(
                      child: _PrayerCard(
                        prayer: p,
                        isActive: prayer.isPrayerActive(p),
                        isPassed: prayer.isPrayerPassed(p),
                        colors: colors,
                        index: i,
                      ),
                    );
                  },
                  childCount: prayer.times!.prayers.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ] else
              SliverFillRemaining(
                child: _NoLocationPlaceholder(onTap: _goToLocation),
              ),
          ],
        ),
      ),
    );
  }

  void _goToLocation() {
    DefaultTabController.of(context).animateTo(2);
  }
}

// ─── Hero Header with live clock ──────────────────────────────────────────

class _HeroHeader extends StatefulWidget {
  final String? cityName;
  final AppColors colors;

  const _HeroHeader({required this.cityName, required this.colors});

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final timeStr = DateFormat('HH:mm').format(_now);
    final secStr  = DateFormat(':ss').format(_now);
    final prayer  = context.watch<PrayerProvider>();
    final hijri   = prayer.times?.hijri;

    return ClipRRect(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B3D2A), Color(0xFF2E6645), Color(0xFF3D7A55)],
          ),
        ),
        child: Stack(
          children: [
            // Decorative background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _HeaderDecorPainter(),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: city + hijri chip
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.cityName != null) ...[
                        const Icon(Icons.location_on_rounded,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: AppText(
                            text: widget.cityName!,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (hijri != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1),
                          ),
                          child: AppText(
                            text:
                                '${hijri.day} ${'months_hijri.${hijri.month}'.tr()}',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Big clock
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 64,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        secStr,
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.55),
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Gregorian date
                  AppText(
                    text: _localizedDate(context, _now),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.70),
                    letterSpacing: 0.2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _localizedDate(BuildContext context, DateTime dt) {
    final lang = AppSettings.language;
    if (lang == 'en') {
      return DateFormat('EEEE, d MMMM', 'en').format(dt);
    } else if (lang == 'ky') {
      // Kyrgyz uses Russian locale for formatting
      return DateFormat('EEEE, d MMMM', 'ru').format(dt);
    }
    return DateFormat('EEEE, d MMMM', 'ru').format(dt);
  }
}

// ─── Header decorative painter ───────────────────────────────────────────

class _HeaderDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Large crescent moon (top-right)
    final moonCenter = Offset(size.width + 10, -10);
    const moonR = 110.0;
    canvas.drawCircle(moonCenter, moonR, paint);
    // Mask the inner part of crescent
    final maskPaint = Paint()
      ..color = const Color(0xFF2E6645).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.srcOver;
    canvas.drawCircle(Offset(size.width + 38, 14), moonR * 0.85, maskPaint);

    // Geometric dots grid (subtle)
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += 28) {
      for (double y = 0; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }

    // Star in top-left area
    _drawStar(canvas, const Offset(32, 28), 7, paint..strokeWidth = 1.0);
    _drawStar(canvas, const Offset(68, 14), 4, paint..strokeWidth = 0.8);
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
  bool shouldRepaint(_HeaderDecorPainter old) => false;
}

// ─── Next Prayer Banner ────────────────────────────────────────────────────

class _NextPrayerBanner extends StatelessWidget {
  final PrayerProvider prayer;
  final AppColors colors;

  const _NextPrayerBanner({required this.prayer, required this.colors});

  @override
  Widget build(BuildContext context) {
    final next = prayer.nextPrayer;
    if (next == null) return const SizedBox.shrink();

    final remaining = prayer.remainingTime;
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    final timeStr = h > 0
        ? '${h}h ${m}m'
        : m > 0
            ? '${m}m ${s}s'
            : '${s}s';

    // Progress between last passed prayer and next prayer
    final progress = _computeProgress(prayer);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D6347), Color(0xFF4A8A62), Color(0xFF3D7554)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x385A9A6E),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle pattern in banner
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                painter: _BannerDecorPainter(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: AppText(
                        text: 'home.next_prayer'.tr().toUpperCase(),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    // Countdown pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          AppText(
                            text: 'home.in_time'
                                .tr(namedArgs: {'time': timeStr}),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Prayer name + time row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            text: 'prayers.${next.key}'.tr(),
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'PlayfairDisplay',
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppText(
                          text: next.time,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlayfairDisplay',
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _computeProgress(PrayerProvider p) {
    final prayers = p.times?.prayers ?? [];
    if (prayers.isEmpty) return 0;

    // Find the last passed prayer and the next prayer
    PrayerEntry? lastPassed;
    PrayerEntry? nextPrayer;
    for (final prayer in prayers) {
      if (p.isPrayerPassed(prayer)) {
        lastPassed = prayer;
      } else if (nextPrayer == null) {
        nextPrayer = prayer;
      }
    }

    if (nextPrayer == null) return 1.0;

    final now = DateTime.now();
    final nextDt = nextPrayer.toDateTime();
    if (nextDt == null) return 0;

    DateTime? startDt;
    if (lastPassed != null) {
      startDt = lastPassed.toDateTime();
    } else {
      // Before first prayer — use midnight as start
      startDt = DateTime(now.year, now.month, now.day, 0, 0);
    }

    if (startDt == null) return 0;
    final total = nextDt.difference(startDt).inSeconds;
    final elapsed = now.difference(startDt).inSeconds;
    if (total <= 0) return 0;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class _BannerDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Large semi-circle in top-right
    canvas.drawCircle(
      Offset(size.width + 20, -20),
      size.height * 0.85,
      paint,
    );
    // Small circle bottom-left
    canvas.drawCircle(
      Offset(-10, size.height + 10),
      size.height * 0.4,
      paint,
    );
  }

  @override
  bool shouldRepaint(_BannerDecorPainter old) => false;
}

// ─── Prayer Card ──────────────────────────────────────────────────────────

class _PrayerCard extends StatefulWidget {
  final PrayerEntry prayer;
  final bool isActive;
  final bool isPassed;
  final AppColors colors;
  final int index;

  const _PrayerCard({
    required this.prayer,
    required this.isActive,
    required this.isPassed,
    required this.colors,
    required this.index,
  });

  @override
  State<_PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<_PrayerCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _activeCtrl;
  late Animation<double> _activeAnim;

  static const _icons = {
    'fajr':    Icons.wb_twilight_rounded,
    'sunrise': Icons.wb_sunny_outlined,
    'dhuhr':   Icons.wb_sunny_rounded,
    'asr':     Icons.sunny_snowing,
    'maghrib': Icons.wb_twilight_rounded,
    'isha':    Icons.nights_stay_rounded,
  };

  // Gradient pairs per prayer
  static const _gradients = {
    'fajr':    [Color(0xFF6B9EAA), Color(0xFF3D7089)],
    'sunrise': [Color(0xFFE8A825), Color(0xFFF5C842)],
    'dhuhr':   [Color(0xFFC8952A), Color(0xFFE5A935)],
    'asr':     [Color(0xFF7A9E5E), Color(0xFF5A8040)],
    'maghrib': [Color(0xFFB05A3A), Color(0xFFD4724A)],
    'isha':    [Color(0xFF4A5B8A), Color(0xFF6374AA)],
  };

  @override
  void initState() {
    super.initState();
    _activeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _activeAnim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _activeCtrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _activeCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PrayerCard old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_activeCtrl.isAnimating) {
      _activeCtrl.repeat(reverse: true);
    } else if (!widget.isActive && _activeCtrl.isAnimating) {
      _activeCtrl.stop();
      _activeCtrl.reset();
    }
  }

  @override
  void dispose() {
    _activeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isActive = widget.isActive;
    final isPassed = widget.isPassed;
    final gradColors = _gradients[widget.prayer.key] ??
        [colors.primary, colors.primaryDark];

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        transform: Matrix4.identity()
          ..translate(0.0, _pressed ? 1.0 : 0.0)
          ..scale(_pressed ? 0.99 : 1.0),
        decoration: BoxDecoration(
          color: isActive ? colors.primaryFill : colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? colors.primary.withValues(alpha: 0.6) : colors.border,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppColors.elevation1,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon container with gradient
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: isPassed || !isActive
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradColors,
                        ),
                  color: isActive
                      ? null
                      : isPassed
                          ? colors.disabled
                          : colors.primaryFill,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _icons[widget.prayer.key] ?? Icons.access_time_rounded,
                  size: 22,
                  color: isActive
                      ? Colors.white
                      : isPassed
                          ? colors.textTertiary
                          : colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      text: 'prayers.${widget.prayer.key}'.tr(),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPassed
                          ? colors.textTertiary
                          : isActive
                              ? colors.primaryDark
                              : colors.text,
                    ),
                    if (isPassed)
                      AppText(
                        text: 'home.passed'.tr(),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textTertiary,
                        letterSpacing: 0.2,
                      ),
                    if (isActive)
                      AppText(
                        text: 'home.now'.tr(),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                        letterSpacing: 0.2,
                      ),
                  ],
                ),
              ),
              // Time
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppText(
                    text: widget.prayer.time,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'PlayfairDisplay',
                    color: isActive
                        ? colors.primaryDark
                        : isPassed
                            ? colors.textTertiary
                            : colors.text,
                  ),
                  const SizedBox(width: 8),
                  // Status indicator
                  if (isActive)
                    AnimatedBuilder(
                      animation: _activeAnim,
                      builder: (_, __) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary
                              .withValues(alpha: _activeAnim.value),
                        ),
                      ),
                    )
                  else if (isPassed)
                    Icon(Icons.check_rounded, size: 16, color: colors.textTertiary)
                  else
                    SizedBox(width: 16, child: Icon(Icons.chevron_right_rounded, size: 16, color: colors.border)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── No Location Placeholder ─────────────────────────────────────────────

class _NoLocationPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _NoLocationPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colors.primaryFill,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🕌', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 20),
            AppText(
              text: 'home.no_location'.tr(),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'PlayfairDisplay',
              color: colors.text,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              text: 'home.no_location_hint'.tr(),
              fontSize: 14,
              color: colors.textSecondary,
              textAlign: TextAlign.center,
              height: 1.5,
            ),
            const SizedBox(height: 28),
            AppButton(
              text: 'home.select_location'.tr(),
              onPressed: onTap,
              icon: Icons.location_on_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final AppColors colors;
  const _LoadingView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colors.primary, strokeWidth: 2.5),
          const SizedBox(height: 16),
          AppText(
            text: 'home.loading'.tr(),
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final AppColors colors;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
            const SizedBox(height: 16),
            AppText(
              text: 'home.error'.tr(),
              fontSize: 18,
              fontFamily: 'PlayfairDisplay',
              color: colors.text,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              text: message,
              fontSize: 13,
              color: colors.textSecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'home.retry'.tr(),
              onPressed: onRetry,
              variant: AppButtonVariant.outline,
            ),
          ],
        ),
      ),
    );
  }
}

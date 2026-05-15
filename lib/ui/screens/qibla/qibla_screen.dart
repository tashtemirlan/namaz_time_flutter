import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../providers/location_provider.dart';
import '../../../services/qibla_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_extensions.dart';
import '../../widgets/app/app_text.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen>
    with SingleTickerProviderStateMixin {
  double _heading = 0;
  double _qiblaBearing = 0;
  bool _hasCompass = false;
  bool _hasLocation = false;
  bool _usingGps = false;
  double? _gpsAccuracy;
  bool _loadingGps = false;
  String? _sourceName;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnim = Tween(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initFromSavedLocation();
    _listenCompass();
  }

  /// Seed qibla bearing from the saved city location (quick, no GPS needed).
  void _initFromSavedLocation() {
    final loc = context.read<LocationProvider>().location;
    if (loc?.latitude != null && loc?.longitude != null) {
      _qiblaBearing =
          QiblaService.getQiblaBearing(loc!.latitude!, loc.longitude!);
      _hasLocation = true;
      _sourceName = loc.cityName;
    }
  }

  void _listenCompass() {
    FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading != null) {
        setState(() {
          _heading = heading;
          _hasCompass = true;
        });

        // Pulse when aligned (±5°)
        final diff = ((_heading - _qiblaBearing) % 360 + 360) % 360;
        final aligned = diff < 5 || diff > 355;
        if (aligned && !_pulseCtrl.isAnimating) {
          _pulseCtrl.repeat(reverse: true);
        } else if (!aligned && _pulseCtrl.isAnimating) {
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      }
    });
  }

  /// Fetch real GPS coordinates and recompute bearing.
  Future<void> _fetchGps() async {
    setState(() => _loadingGps = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() => _loadingGps = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      setState(() {
        _qiblaBearing =
            QiblaService.getQiblaBearing(pos.latitude, pos.longitude);
        _hasLocation = true;
        _usingGps = true;
        _gpsAccuracy = pos.accuracy;
        _loadingGps = false;
        _sourceName = null; // clear city name — now using GPS
      });
    } catch (_) {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(colors),
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: colors.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  text: 'qibla.title'.tr(),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'PlayfairDisplay',
                  color: colors.text,
                ),
                // Source indicator
                if (_hasLocation)
                  AppText(
                    text: _usingGps
                        ? 'qibla.using_gps'.tr(namedArgs: {
                            'm': (_gpsAccuracy ?? 0).toStringAsFixed(0)
                          })
                        : 'qibla.using_city'
                            .tr(namedArgs: {'city': _sourceName ?? ''}),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
              ],
            ),
          ),
          // Bearing chip
          if (_hasLocation)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primaryFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.primaryPale),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore_outlined,
                      size: 14, color: colors.primaryDark),
                  const SizedBox(width: 4),
                  AppText(
                    text: '${_qiblaBearing.toStringAsFixed(0)}°',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryDark,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          // GPS button
          _GpsButton(
            loading: _loadingGps,
            usingGps: _usingGps,
            colors: colors,
            onTap: _fetchGps,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (!_hasLocation) {
      return _NoLocationView(colors: colors, onGpsTap: _fetchGps);
    }
    if (!_hasCompass) {
      return _LoadingCompassView(colors: colors);
    }
    return _CompassView(
      heading: _heading,
      qiblaBearing: _qiblaBearing,
      pulseAnim: _pulseAnim,
      colors: colors,
    );
  }
}

// ─── GPS button ───────────────────────────────────────────────────────────

class _GpsButton extends StatelessWidget {
  final bool loading;
  final bool usingGps;
  final AppColors colors;
  final VoidCallback onTap;

  const _GpsButton({
    required this.loading,
    required this.usingGps,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: usingGps ? colors.primary : colors.primaryFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: usingGps ? colors.primaryDark : colors.primaryPale,
          ),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: usingGps ? Colors.white : colors.primary,
                  ),
                )
              : Icon(
                  Icons.gps_fixed_rounded,
                  size: 20,
                  color: usingGps ? Colors.white : colors.primary,
                ),
        ),
      ),
    );
  }
}

// ─── Compass View ─────────────────────────────────────────────────────────

class _CompassView extends StatelessWidget {
  final double heading;
  final double qiblaBearing;
  final Animation<double> pulseAnim;
  final AppColors colors;

  const _CompassView({
    required this.heading,
    required this.qiblaBearing,
    required this.pulseAnim,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final qiblaAngle = (qiblaBearing - heading) * math.pi / 180;
    final diff = ((heading - qiblaBearing) % 360 + 360) % 360;
    final isAligned = diff < 5 || diff > 355;

    return Column(
      children: [
        const SizedBox(height: 16),
        AppText(
          text: 'qibla.subtitle'.tr(),
          fontSize: 14,
          color: colors.textSecondary,
        ),
        const Spacer(),
        Center(
          child: ScaleTransition(
            scale: isAligned ? pulseAnim : const AlwaysStoppedAnimation(1.0),
            child: _CompassWidget(
              compassAngle: -heading * math.pi / 180,
              qiblaAngle: qiblaAngle,
              isAligned: isAligned,
              colors: colors,
            ),
          ),
        ),
        const SizedBox(height: 28),
        _DirectionInfo(
          heading: heading,
          qiblaBearing: qiblaBearing,
          isAligned: isAligned,
          colors: colors,
        ),
        const SizedBox(height: 14),
        AppText(
          text: 'qibla.calibrate'.tr(),
          fontSize: 12,
          color: colors.textTertiary,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _CompassWidget extends StatelessWidget {
  final double compassAngle;
  final double qiblaAngle;
  final bool isAligned;
  final AppColors colors;

  const _CompassWidget({
    required this.compassAngle,
    required this.qiblaAngle,
    required this.isAligned,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.75;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.card,
              border: Border.all(color: colors.border, width: 2),
              boxShadow: AppColors.elevation2,
            ),
          ),
          // Compass rose (rotates with device heading)
          Transform.rotate(
            angle: compassAngle,
            child: CustomPaint(
              size: Size(size, size),
              painter: _CompassRosePainter(colors: colors),
            ),
          ),
          // Qibla needle (compensated for heading → points to Mecca)
          Transform.rotate(
            angle: qiblaAngle,
            child: _QiblaNeedle(
                size: size * 0.72, isAligned: isAligned, colors: colors),
          ),
          // Center dot
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAligned ? colors.primary : colors.surface,
              border: Border.all(
                color: isAligned ? colors.primaryDark : colors.border,
                width: 2.5,
              ),
              boxShadow: AppColors.elevation1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassRosePainter extends CustomPainter {
  final AppColors colors;
  _CompassRosePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()
      ..color = colors.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 360; i += 5) {
      final angle = i * math.pi / 180;
      final isMajor = i % 45 == 0;
      final isMinor = i % 15 == 0;
      final tickLen = isMajor ? 20.0 : isMinor ? 12.0 : 6.0;
      paint.strokeWidth = isMajor ? 2 : 1;
      paint.color = isMajor
          ? colors.text
          : isMinor
              ? colors.textSecondary
              : colors.border;

      final outer = Offset(
        center.dx + (r - 8) * math.cos(angle - math.pi / 2),
        center.dy + (r - 8) * math.sin(angle - math.pi / 2),
      );
      final inner = Offset(
        center.dx + (r - 8 - tickLen) * math.cos(angle - math.pi / 2),
        center.dy + (r - 8 - tickLen) * math.sin(angle - math.pi / 2),
      );
      canvas.drawLine(outer, inner, paint);
    }

    // Cardinal labels
    final labels = ['N', 'E', 'S', 'W'];
    final labelAngles = [0.0, math.pi / 2, math.pi, 3 * math.pi / 2];
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (int i = 0; i < 4; i++) {
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: labels[i] == 'N' ? colors.error : colors.text,
        ),
      );
      textPainter.layout();
      final pos = Offset(
        center.dx +
            (r - 36) * math.cos(labelAngles[i] - math.pi / 2) -
            textPainter.width / 2,
        center.dy +
            (r - 36) * math.sin(labelAngles[i] - math.pi / 2) -
            textPainter.height / 2,
      );
      textPainter.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(_CompassRosePainter old) => false;
}

class _QiblaNeedle extends StatelessWidget {
  final double size;
  final bool isAligned;
  final AppColors colors;

  const _QiblaNeedle(
      {required this.size, required this.isAligned, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tip — label + needle pointing to Qibla
          Positioned(
            top: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAligned
                          ? [colors.primary, colors.primaryDark]
                          : [const Color(0xFF3D7554), const Color(0xFF2D5A3D)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isAligned ? AppColors.glowPrimary : [],
                  ),
                  child: AppText(
                    text: 'qibla.mecca'.tr(),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                CustomPaint(
                  size: Size(14, size * 0.30),
                  painter: _NeedlePainter(
                    color: isAligned ? colors.primary : const Color(0xFF3D7554),
                  ),
                ),
              ],
            ),
          ),
          // Tail
          Positioned(
            bottom: 0,
            child: CustomPaint(
              size: Size(14, size * 0.30),
              painter:
                  _NeedlePainter(color: colors.border, isBase: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  final Color color;
  final bool isBase;
  _NeedlePainter({required this.color, this.isBase = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (!isBase) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => old.color != color;
}

class _DirectionInfo extends StatelessWidget {
  final double heading;
  final double qiblaBearing;
  final bool isAligned;
  final AppColors colors;

  const _DirectionInfo({
    required this.heading,
    required this.qiblaBearing,
    required this.isAligned,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isAligned ? colors.primaryFill : colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAligned ? colors.primary : colors.border,
          width: isAligned ? 1.5 : 1,
        ),
        boxShadow: isAligned
            ? [
                BoxShadow(
                    color: colors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
            : AppColors.elevation1,
      ),
      child: Center(
        child: isAligned
            ? AppText(
                text: 'qibla.aligned'.tr(),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              )
            : AppText(
                text: 'qibla.degrees'
                    .tr(namedArgs: {'degrees': qiblaBearing.toStringAsFixed(1)}),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.text,
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}

// ─── Placeholder views ────────────────────────────────────────────────────

class _NoLocationView extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onGpsTap;
  const _NoLocationView({required this.colors, required this.onGpsTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                  color: colors.primaryFill, shape: BoxShape.circle),
              child: const Center(
                  child: Text('🧭', style: TextStyle(fontSize: 44))),
            ),
            const SizedBox(height: 20),
            AppText(
              text: 'qibla.title'.tr(),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'PlayfairDisplay',
              color: colors.text,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              text: 'qibla.location_needed'.tr(),
              fontSize: 14,
              color: colors.textSecondary,
              textAlign: TextAlign.center,
              height: 1.48,
            ),
            const SizedBox(height: 24),
            // GPS shortcut button
            GestureDetector(
              onTap: onGpsTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.glowPrimary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed_rounded,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    AppText(
                      text: 'qibla.use_gps'.tr(),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCompassView extends StatelessWidget {
  final AppColors colors;
  const _LoadingCompassView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧭', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          CircularProgressIndicator(color: colors.primary, strokeWidth: 2.5),
          const SizedBox(height: 16),
          AppText(
            text: 'common.loading'.tr(),
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}

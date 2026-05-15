import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/qibla/qibla_screen.dart';
import '../screens/location/location_picker_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_extensions.dart';
import '../widgets/app/app_text.dart';

class AppBottomNavBar extends StatefulWidget {
  const AppBottomNavBar({super.key});

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // IndexedStack — all screens mount once, never rebuilt on tab switch
  static const _screens = [
    HomeScreen(),
    QiblaScreen(),
    LocationPickerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colors.background,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: _NavBar(
          currentIndex: _currentIndex,
          colors: colors,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int currentIndex;
  final AppColors colors;
  final ValueChanged<int> onTap;

  const _NavBar({
    required this.currentIndex,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded,          Icons.home_outlined,          'nav.home'),
      (Icons.explore_rounded,       Icons.explore_outlined,       'nav.qibla'),
      (Icons.location_on_rounded,   Icons.location_on_outlined,   'nav.location'),
      (Icons.settings_rounded,      Icons.settings_outlined,      'nav.settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isActive ? 24 : 0,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Icon(
                        isActive ? item.$1 : item.$2,
                        size: 22,
                        color: isActive ? colors.primary : colors.textTertiary,
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        text: item.$3.tr(),
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? colors.primary : colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

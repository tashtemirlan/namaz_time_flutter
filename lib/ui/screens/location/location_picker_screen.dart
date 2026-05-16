import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/kg_locations.dart';
import '../../../data/world_locations.dart';
import '../../../models/location_model.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/prayer_provider.dart';
import '../../../services/notification_service.dart';
import '../../../global/app_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_extensions.dart';
import '../../widgets/app/app_text.dart';
import '../../widgets/app/app_text_field.dart';
import '../../widgets/app/app_snack_bar.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final savedLoc = context.watch<LocationProvider>().location;

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(
            child: Container(
              color: colors.surface,
              child: SafeArea(
                bottom: false,
                child: Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        AppText(
                          text: 'location.title'.tr(),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlayfairDisplay',
                          color: colors.text,
                        ),
                        const Spacer(),
                        if (savedLoc != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.primaryFill,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.primaryPale),
                            ),
                            child: AppText(
                              text: savedLoc.cityName,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.primaryDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: AppTextField(
                      controller: _searchCtrl,
                      hintText: 'location.search_hint'.tr(),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20, color: colors.textTertiary),
                    ),
                  ),
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: colors.primary,
                    labelColor: colors.primary,
                    unselectedLabelColor: colors.textSecondary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(text: 'location.kyrgyzstan'.tr()),
                      Tab(text: 'location.worldwide'.tr()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _KyrgyzstanTab(searchQuery: _searchQuery, onSelect: _onSelect),
            _WorldwideTab(searchQuery: _searchQuery, onSelect: _onSelect),
          ],
        ),
      ),
    );
  }

  Future<void> _onSelect(AppLocation location) async {
    final locProv = context.read<LocationProvider>();
    final prayerProv = context.read<PrayerProvider>();

    await locProv.setLocation(location);
    await prayerProv.load(location);

    if (!mounted) return;

    final times = prayerProv.times;
    if (times != null) {
      await NotificationService.schedulePrayerNotifications(
          times, AppSettings.language);
    } else {
      await NotificationService.refreshScheduleForToday();
    }

    AppSnackBar.success(
      context,
      title: 'location.saved'.tr(),
      message: location.toString(),
    );
  }
}

// ─── Kyrgyzstan Tab ───────────────────────────────────────────────────────

class _KyrgyzstanTab extends StatelessWidget {
  final String searchQuery;
  final Future<void> Function(AppLocation) onSelect;

  const _KyrgyzstanTab({required this.searchQuery, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final savedLoc = context.watch<LocationProvider>().location;

    final filtered = _filterKgRegions(kgRegions, searchQuery);

    if (filtered.isEmpty) {
      return _EmptySearch(colors: colors);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final region = filtered[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: AppText(
                text: region.key.tr(),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            ...region.cities.map((city) {
              final loc = AppLocation(
                countryCode: 'KG',
                countryName: 'location.kyrgyzstan'.tr(),
                cityName: city.name,
                kgLocationCode: city.kgCode,
                latitude: city.lat,
                longitude: city.lng,
                isKyrgyzstan: true,
              );
              final isSelected = savedLoc?.cityName == city.name &&
                  savedLoc?.isKyrgyzstan == true;
              return _CityTile(
                city: city,
                isSelected: isSelected,
                colors: colors,
                onTap: () => onSelect(loc),
              );
            }),
          ],
        );
      },
    );
  }

  List<RegionEntry> _filterKgRegions(
      List<RegionEntry> regions, String query) {
    if (query.isEmpty) return regions;
    return regions
        .map((r) {
          final cities = r.cities.where((c) {
            final name = c.name.toLowerCase();
            final nameRu = c.nameRu.toLowerCase();
            return name.contains(query) || nameRu.contains(query);
          }).toList();
          return RegionEntry(key: r.key, nameRu: r.nameRu, cities: cities);
        })
        .where((r) => r.cities.isNotEmpty)
        .toList();
  }
}

// ─── Worldwide Tab ────────────────────────────────────────────────────────

class _WorldwideTab extends StatelessWidget {
  final String searchQuery;
  final Future<void> Function(AppLocation) onSelect;

  const _WorldwideTab({required this.searchQuery, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final savedLoc = context.watch<LocationProvider>().location;

    final filtered = _filterWorld(worldCountries, searchQuery);

    if (filtered.isEmpty) {
      return _EmptySearch(colors: colors);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final country = filtered[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  AppText(
                    text: country.nameRu,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'PlayfairDisplay',
                    color: colors.text,
                  ),
                  const SizedBox(width: 8),
                  AppText(
                    text: country.code,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ],
              ),
            ),
            ...country.regions.expand((r) => r.cities).map((city) {
              final loc = AppLocation(
                countryCode: country.code,
                countryName: country.nameRu,
                cityName: city.nameRu,
                latitude: city.lat,
                longitude: city.lng,
                isKyrgyzstan: false,
              );
              final isSelected = savedLoc?.cityName == city.nameRu &&
                  savedLoc?.countryCode == country.code;
              return _CityTile(
                city: city,
                isSelected: isSelected,
                colors: colors,
                onTap: () => onSelect(loc),
              );
            }),
          ],
        );
      },
    );
  }

  List<CountryEntry> _filterWorld(List<CountryEntry> countries, String query) {
    if (query.isEmpty) return countries;
    return countries.where((c) {
      final countryMatch = c.nameRu.toLowerCase().contains(query) ||
          c.code.toLowerCase().contains(query);
      final cityMatch = c.regions.any((r) => r.cities.any((city) =>
          city.name.toLowerCase().contains(query) ||
          city.nameRu.toLowerCase().contains(query)));
      return countryMatch || cityMatch;
    }).toList();
  }
}

// ─── City Tile ────────────────────────────────────────────────────────────

class _CityTile extends StatelessWidget {
  final CityEntry city;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  const _CityTile({
    required this.city,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryFill : null,
          border: Border(
            bottom: BorderSide(color: colors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.primaryFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.location_city_rounded,
                size: 18,
                color: isSelected ? Colors.white : colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppText(
                text: city.name,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? colors.primaryDark : colors.text,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 20, color: colors.primary)
            else
              Icon(Icons.chevron_right_rounded, size: 14, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final AppColors colors;
  const _EmptySearch({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔍', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          AppText(
            text: 'location.empty_search'.tr(),
            fontSize: 16,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}

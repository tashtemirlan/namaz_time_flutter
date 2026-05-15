/// Represents user's chosen location for prayer time fetching.
class AppLocation {
  final String countryCode;   // 'KG' | ISO country code
  final String countryName;   // "Кыргызстан"
  final String cityName;      // "Бишкек"
  final int? kgLocationCode;  // For muftiyat.kg only
  final double? latitude;
  final double? longitude;
  final bool isKyrgyzstan;

  const AppLocation({
    required this.countryCode,
    required this.countryName,
    required this.cityName,
    this.kgLocationCode,
    this.latitude,
    this.longitude,
    this.isKyrgyzstan = false,
  });

  factory AppLocation.fromJson(Map<String, dynamic> json) {
    return AppLocation(
      countryCode:    json['countryCode'] as String,
      countryName:    json['countryName'] as String,
      cityName:       json['cityName'] as String,
      kgLocationCode: json['kgLocationCode'] as int?,
      latitude:       (json['latitude'] as num?)?.toDouble(),
      longitude:      (json['longitude'] as num?)?.toDouble(),
      isKyrgyzstan:   json['isKyrgyzstan'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'countryCode':    countryCode,
    'countryName':    countryName,
    'cityName':       cityName,
    'kgLocationCode': kgLocationCode,
    'latitude':       latitude,
    'longitude':      longitude,
    'isKyrgyzstan':   isKyrgyzstan,
  };

  @override
  String toString() => '$cityName, $countryName';
}

/// A single city entry in the location picker.
class CityEntry {
  final String name;
  final String nameRu;
  final int? kgCode;
  final double? lat;
  final double? lng;

  const CityEntry({
    required this.name,
    required this.nameRu,
    this.kgCode,
    this.lat,
    this.lng,
  });
}

/// A region grouping cities (for Kyrgyzstan oblasts or country groupings).
class RegionEntry {
  final String key;       // translation key, e.g. 'location.batken'
  final String nameRu;    // fallback name
  final List<CityEntry> cities;

  const RegionEntry({
    required this.key,
    required this.nameRu,
    required this.cities,
  });
}

/// Top-level country entry.
class CountryEntry {
  final String code;      // ISO 2-letter
  final String nameRu;
  final bool isKyrgyzstan;
  final List<RegionEntry> regions;

  const CountryEntry({
    required this.code,
    required this.nameRu,
    this.isKyrgyzstan = false,
    required this.regions,
  });
}

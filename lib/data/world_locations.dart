import '../models/location_model.dart';

/// Major world countries and their cities for AlAdhan API.
/// City name and country code are passed as query params to AlAdhan.
const List<CountryEntry> worldCountries = [
  CountryEntry(
    code: 'RU', nameRu: 'Россия',
    regions: [
      RegionEntry(key: 'Россия', nameRu: 'Россия', cities: [
        CityEntry(name: 'Moscow',       nameRu: 'Москва',         lat: 55.7558, lng: 37.6176),
        CityEntry(name: 'Saint Petersburg', nameRu: 'Санкт-Петербург', lat: 59.9343, lng: 30.3351),
        CityEntry(name: 'Kazan',        nameRu: 'Казань',         lat: 55.7964, lng: 49.1089),
        CityEntry(name: 'Ufa',          nameRu: 'Уфа',            lat: 54.7388, lng: 55.9721),
        CityEntry(name: 'Makhachkala', nameRu: 'Махачкала',      lat: 42.9849, lng: 47.5047),
        CityEntry(name: 'Grozny',       nameRu: 'Грозный',        lat: 43.3178, lng: 45.6984),
        CityEntry(name: 'Novosibirsk',  nameRu: 'Новосибирск',    lat: 54.9885, lng: 82.9207),
        CityEntry(name: 'Yekaterinburg',nameRu: 'Екатеринбург',   lat: 56.8389, lng: 60.6057),
      ]),
    ],
  ),
  CountryEntry(
    code: 'KZ', nameRu: 'Казахстан',
    regions: [
      RegionEntry(key: 'Казахстан', nameRu: 'Казахстан', cities: [
        CityEntry(name: 'Astana',   nameRu: 'Астана',   lat: 51.1801, lng: 71.4460),
        CityEntry(name: 'Almaty',   nameRu: 'Алматы',   lat: 43.2220, lng: 76.8512),
        CityEntry(name: 'Shymkent', nameRu: 'Шымкент',  lat: 42.3000, lng: 69.5999),
        CityEntry(name: 'Aktobe',   nameRu: 'Актобе',   lat: 50.2797, lng: 57.2068),
        CityEntry(name: 'Taraz',    nameRu: 'Тараз',    lat: 42.9000, lng: 71.3667),
      ]),
    ],
  ),
  CountryEntry(
    code: 'UZ', nameRu: 'Узбекистан',
    regions: [
      RegionEntry(key: 'Узбекистан', nameRu: 'Узбекистан', cities: [
        CityEntry(name: 'Tashkent',   nameRu: 'Ташкент',    lat: 41.2995, lng: 69.2401),
        CityEntry(name: 'Samarkand',  nameRu: 'Самарканд',  lat: 39.6542, lng: 66.9597),
        CityEntry(name: 'Bukhara',    nameRu: 'Бухара',     lat: 39.7681, lng: 64.4556),
        CityEntry(name: 'Namangan',   nameRu: 'Наманган',   lat: 41.0011, lng: 71.6633),
        CityEntry(name: 'Andijan',    nameRu: 'Андижан',    lat: 40.7821, lng: 72.3442),
        CityEntry(name: 'Fergana',    nameRu: 'Фергана',    lat: 40.3834, lng: 71.7876),
      ]),
    ],
  ),
  CountryEntry(
    code: 'TR', nameRu: 'Турция',
    regions: [
      RegionEntry(key: 'Турция', nameRu: 'Турция', cities: [
        CityEntry(name: 'Istanbul',  nameRu: 'Стамбул',  lat: 41.0082, lng: 28.9784),
        CityEntry(name: 'Ankara',    nameRu: 'Анкара',   lat: 39.9334, lng: 32.8597),
        CityEntry(name: 'Izmir',     nameRu: 'Измир',    lat: 38.4237, lng: 27.1428),
        CityEntry(name: 'Bursa',     nameRu: 'Бурса',    lat: 40.1826, lng: 29.0665),
        CityEntry(name: 'Antalya',   nameRu: 'Анталья',  lat: 36.8841, lng: 30.7056),
      ]),
    ],
  ),
  CountryEntry(
    code: 'SA', nameRu: 'Саудовская Аравия',
    regions: [
      RegionEntry(key: 'Саудовская Аравия', nameRu: 'Саудовская Аравия', cities: [
        CityEntry(name: 'Mecca',  nameRu: 'Мекка',   lat: 21.3891, lng: 39.8579),
        CityEntry(name: 'Medina', nameRu: 'Медина',  lat: 24.4672, lng: 39.6151),
        CityEntry(name: 'Riyadh', nameRu: 'Эр-Рияд', lat: 24.7136, lng: 46.6753),
        CityEntry(name: 'Jeddah', nameRu: 'Джидда',  lat: 21.5433, lng: 39.1728),
      ]),
    ],
  ),
  CountryEntry(
    code: 'AE', nameRu: 'ОАЭ',
    regions: [
      RegionEntry(key: 'ОАЭ', nameRu: 'ОАЭ', cities: [
        CityEntry(name: 'Dubai',      nameRu: 'Дубай',         lat: 25.2048, lng: 55.2708),
        CityEntry(name: 'Abu Dhabi',  nameRu: 'Абу-Даби',      lat: 24.4539, lng: 54.3773),
        CityEntry(name: 'Sharjah',    nameRu: 'Шарджа',        lat: 25.3573, lng: 55.4033),
      ]),
    ],
  ),
  CountryEntry(
    code: 'EG', nameRu: 'Египет',
    regions: [
      RegionEntry(key: 'Египет', nameRu: 'Египет', cities: [
        CityEntry(name: 'Cairo',       nameRu: 'Каир',     lat: 30.0444, lng: 31.2357),
        CityEntry(name: 'Alexandria',  nameRu: 'Александрия', lat: 31.2001, lng: 29.9187),
      ]),
    ],
  ),
  CountryEntry(
    code: 'DE', nameRu: 'Германия',
    regions: [
      RegionEntry(key: 'Германия', nameRu: 'Германия', cities: [
        CityEntry(name: 'Berlin',   nameRu: 'Берлин',   lat: 52.5200, lng: 13.4050),
        CityEntry(name: 'Munich',   nameRu: 'Мюнхен',   lat: 48.1351, lng: 11.5820),
        CityEntry(name: 'Hamburg',  nameRu: 'Гамбург',  lat: 53.5511, lng: 9.9937),
        CityEntry(name: 'Cologne',  nameRu: 'Кёльн',    lat: 50.9333, lng: 6.9500),
        CityEntry(name: 'Frankfurt',nameRu: 'Франкфурт',lat: 50.1109, lng: 8.6821),
      ]),
    ],
  ),
  CountryEntry(
    code: 'GB', nameRu: 'Великобритания',
    regions: [
      RegionEntry(key: 'Великобритания', nameRu: 'Великобритания', cities: [
        CityEntry(name: 'London',     nameRu: 'Лондон',     lat: 51.5074, lng: -0.1278),
        CityEntry(name: 'Birmingham', nameRu: 'Бирмингем',  lat: 52.4862, lng: -1.8904),
        CityEntry(name: 'Manchester', nameRu: 'Манчестер',  lat: 53.4808, lng: -2.2426),
        CityEntry(name: 'Bradford',   nameRu: 'Брадфорд',   lat: 53.7950, lng: -1.7594),
      ]),
    ],
  ),
  CountryEntry(
    code: 'US', nameRu: 'США',
    regions: [
      RegionEntry(key: 'США', nameRu: 'США', cities: [
        CityEntry(name: 'New York',   nameRu: 'Нью-Йорк',    lat: 40.7128, lng: -74.0060),
        CityEntry(name: 'Los Angeles',nameRu: 'Лос-Анджелес',lat: 34.0522, lng: -118.2437),
        CityEntry(name: 'Chicago',    nameRu: 'Чикаго',       lat: 41.8781, lng: -87.6298),
        CityEntry(name: 'Houston',    nameRu: 'Хьюстон',      lat: 29.7604, lng: -95.3698),
        CityEntry(name: 'Dearborn',   nameRu: 'Дирборн',      lat: 42.3223, lng: -83.1763),
      ]),
    ],
  ),
  CountryEntry(
    code: 'MY', nameRu: 'Малайзия',
    regions: [
      RegionEntry(key: 'Малайзия', nameRu: 'Малайзия', cities: [
        CityEntry(name: 'Kuala Lumpur', nameRu: 'Куала-Лумпур', lat: 3.1390, lng: 101.6869),
        CityEntry(name: 'George Town',  nameRu: 'Джорджтаун',    lat: 5.4141, lng: 100.3288),
      ]),
    ],
  ),
  CountryEntry(
    code: 'PK', nameRu: 'Пакистан',
    regions: [
      RegionEntry(key: 'Пакистан', nameRu: 'Пакистан', cities: [
        CityEntry(name: 'Karachi',    nameRu: 'Карачи',    lat: 24.8607, lng: 67.0011),
        CityEntry(name: 'Lahore',     nameRu: 'Лахор',     lat: 31.5204, lng: 74.3587),
        CityEntry(name: 'Islamabad',  nameRu: 'Исламабад', lat: 33.7294, lng: 73.0931),
      ]),
    ],
  ),
  CountryEntry(
    code: 'ID', nameRu: 'Индонезия',
    regions: [
      RegionEntry(key: 'Индонезия', nameRu: 'Индонезия', cities: [
        CityEntry(name: 'Jakarta',  nameRu: 'Джакарта',  lat: -6.2088, lng: 106.8456),
        CityEntry(name: 'Surabaya', nameRu: 'Сурабая',   lat: -7.2575, lng: 112.7521),
        CityEntry(name: 'Bandung',  nameRu: 'Бандунг',   lat: -6.9175, lng: 107.6191),
      ]),
    ],
  ),
];

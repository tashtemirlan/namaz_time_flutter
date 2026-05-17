## Localisation (easy_localization)

**Package:** `easy_localization: ^3.0.7`  
**Translation files:** `assets/translations/{lang}.json` — registered in `pubspec.yaml` under `flutter → assets`.

### Supported locales

| Code | Language | Status |
|------|----------|--------|
| `ru` | Русский (Russian) | Primary / fallback |
| `ky` | Кыргызча (Kyrgyz) | Full |
| `en` | English | Full |

Fallback locale is `ru`. If a key is missing in the active locale, `easy_localization` falls back to `ru`.

### Setup in `main.dart`

```dart
// Wrap runApp content with EasyLocalization:
EasyLocalization(
  supportedLocales: [Locale('ru'), Locale('ky'), Locale('en')],
  path: 'assets/translations',
  fallbackLocale: Locale('ru'),
  child: const GulbazaarApp(),
)

// Wire into MaterialApp:
locale: context.locale,
supportedLocales: context.supportedLocales,
localizationsDelegates: context.localizationDelegates,
```

### Using translations in widgets

```dart
import 'package:easy_localization/easy_localization.dart';

// Simple string
AppText(text: tr('cart.title'))

// String with interpolation
tr('auth.check_inbox_message', namedArgs: {'email': email})
tr('product_detail.added_message', namedArgs: {'name': name, 'qty': qty})
```

**Rule:** Never hardcode a user-visible string in a widget. All strings go through `tr()`. No Cyrillic literals in `.dart` files under `lib/ui/`.


### Language picker

The `_LangThemeBar` widget (in `login_screen.dart` and `signup_screen.dart`) renders a `PopupMenuButton<Locale>` that cycles through ru → ky → en. Selecting a locale calls `context.setLocale(locale)` which `easy_localization` persists via `SharedPreferences` automatically.

The language can also be changed from **Profile → About App → Language** section.

---

## Theming (AppSettings / AppTheme)

### Light & dark themes

The design system ships two fully-specified `ThemeData` objects:

```dart
AppTheme.light   // "Lemongrass & Parchment" — warm cream backgrounds
AppTheme.dark    // Deep forest-ink backgrounds
```

Both are built from `AppColors` token sets (`AppColors.light` / `AppColors.dark`) registered as `ThemeExtension<AppColors>`. Access the current token set in any widget via:

```dart
final colors = context.appColors;   // AppColors extension on BuildContext
final isDark  = context.isDark;     // bool convenience getter
```

### Persisted theme mode (`AppSettings`)

**File:** `lib/global/app_settings.dart`  
**Hive box:** `app_settings` (key `theme`)

```dart
// Read reactive notifier (drives MaterialApp):
AppSettings.themeMode   // ValueNotifier<ThemeMode>

// Toggle light ↔ dark (also persists):
AppSettings.toggleTheme()

// Set explicitly:
AppSettings.setTheme(ThemeMode.dark)
```

`AppSettings.init()` must be called in `main()` after `Hive.initFlutter()`.

### Wiring in `MaterialApp`

```dart
ValueListenableBuilder<ThemeMode>(
  valueListenable: AppSettings.themeMode,
  builder: (_, themeMode, __) => MaterialApp(
    theme:     AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    ...
  ),
)
```

### Theme toggle UI

The `_LangThemeBar` widget on the login and signup screens includes a sun/moon `IconButton` that calls `AppSettings.toggleTheme()`. It uses a `ValueListenableBuilder` on `AppSettings.themeMode` to stay in sync without a rebuild of the whole tree.

### Rules

- Never hardcode a `Color` value in a widget. Always use `context.appColors.<token>`.
- Never use `Theme.of(context).brightness` directly — use `context.isDark`.
- Static colours (brand accents, order status chips) that don't change between themes live as `static const` on `AppColors` (e.g. `AppColors.lemongrass`, `AppColors.peach`).

## Imported Claude Cowork project instructions

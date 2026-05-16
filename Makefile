.PHONY: run run-release run-device \
        build-apk build-aab build-ios \
        generate-icons generate-locales \
        analyze test \
        clean clean-hive clear-notifications \
        pods-install pods-update \
        open-android open-ios \
        help

# ─── App Identity ──────────────────────────────────────────────────────────────
APP_ID_ANDROID = kg.teitcorp.namaztime
APP_NAME        = NamazTime
MAIN            = lib/main.dart

# ─── Development ──────────────────────────────────────────────────────────────

setup:
	@echo "📦 Installing Flutter dependencies..."
	@flutter pub get
	@echo "✅ Done"

run: setup
	@echo "🚀 Running $(APP_NAME) in debug mode..."
	@flutter run -t $(MAIN)

run-release: setup
	@echo "🚀 Running $(APP_NAME) in release mode..."
	@flutter run -t $(MAIN) --release

run-device: setup
	@echo "🚀 Running $(APP_NAME) on device $(DEVICE_ID)..."
	@flutter run -t $(MAIN) -d $(DEVICE_ID)

run-profile: setup
	@echo "🔍 Running $(APP_NAME) in profile mode (performance tracing)..."
	@flutter run -t $(MAIN) --profile

# ─── Android Builds ───────────────────────────────────────────────────────────

build-apk: setup
	@echo "📦 Building APK (release)..."
	@flutter build apk -t $(MAIN) --release
	@echo "✅ APK → build/app/outputs/flutter-apk/app-release.apk"

build-apk-debug: setup
	@echo "📦 Building APK (debug)..."
	@flutter build apk -t $(MAIN) --debug
	@echo "✅ APK → build/app/outputs/flutter-apk/app-debug.apk"

build-aab: setup
	@echo "📦 Building App Bundle (release)..."
	@flutter build appbundle -t $(MAIN) --release
	@echo "✅ AAB → build/app/outputs/bundle/release/app-release.aab"

# ─── iOS Builds ───────────────────────────────────────────────────────────────

build-ios: setup
	@echo "📦 Building iOS IPA (release)..."
	@flutter build ipa -t $(MAIN) --release
	@echo "✅ IPA → build/ios/ipa/"

upload-ios: build-ios
	@echo "📤 Opening Transporter to upload IPA..."
	@open -a Transporter build/ios/ipa/*.ipa
	@echo "✅ Transporter opened"

# ─── Assets & Code Generation ─────────────────────────────────────────────────

generate-icons: setup
	@echo "🎨 Generating launcher icons from assets/icon.png..."
	@dart run flutter_launcher_icons
	@echo "✅ Icons generated for Android and iOS"

generate-locales:
	@echo "🌍 Validating translation files (ru / ky / en)..."
	@for lang in ru ky en; do \
	  f="assets/translations/$$lang.json"; \
	  if [ -f "$$f" ]; then \
	    python3 -c "import json,sys; json.load(open('$$f'))" && \
	    echo "  ✅ $$f — valid JSON" || \
	    echo "  ❌ $$f — INVALID JSON"; \
	  else \
	    echo "  ⚠️  $$f — not found"; \
	  fi; \
	done

define TRANSLATIONS_DIFF_PY
import json, sys

def flatten(d, prefix=''):
    keys = set()
    for k, v in d.items():
        full = (prefix + '.' + k) if prefix else k
        if isinstance(v, dict):
            keys |= flatten(v, full)
        else:
            keys.add(full)
    return keys

files = {
    'ru': 'assets/translations/ru.json',
    'ky': 'assets/translations/ky.json',
    'en': 'assets/translations/en.json',
}
data = {lang: flatten(json.load(open(path))) for lang, path in files.items()}
base = data['ru']
ok = True
for lang in ['ky', 'en']:
    missing = base - data[lang]
    extra   = data[lang] - base
    if missing:
        ok = False
        print("  warning: " + lang + " missing " + str(len(missing)) + " key(s):")
        for k in sorted(missing): print("    - " + k)
    if extra:
        print("  info: " + lang + " has " + str(len(extra)) + " extra key(s):")
        for k in sorted(extra): print("    + " + k)
    if not missing and not extra:
        print("  ok: " + lang + " is in sync with ru")
sys.exit(0 if ok else 1)
endef
export TRANSLATIONS_DIFF_PY

translations-diff:
	@echo "🔍 Checking translation key parity (ru is the base)..."
	@printf '%s\n' "$$TRANSLATIONS_DIFF_PY" | python3
	@echo "✅ Key parity check complete"

# ─── Code Quality ─────────────────────────────────────────────────────────────

analyze: setup
	@echo "🔍 Running Flutter analyzer..."
	@flutter analyze
	@echo "✅ Analysis complete"

format:
	@echo "🖌️  Formatting Dart files..."
	@dart format lib/
	@echo "✅ Formatting done"

format-check:
	@echo "🖌️  Checking Dart formatting (no changes)..."
	@dart format --set-exit-if-changed lib/
	@echo "✅ All files are correctly formatted"

test: setup
	@echo "🧪 Running tests..."
	@flutter test
	@echo "✅ Tests complete"

test-coverage: setup
	@echo "🧪 Running tests with coverage..."
	@flutter test --coverage
	@echo "✅ Coverage report → coverage/lcov.info"

# ─── iOS Dependencies ─────────────────────────────────────────────────────────

pods-install:
	@echo "🍎 Installing CocoaPods dependencies..."
	@cd ios && pod install
	@echo "✅ Pods installed"

pods-update:
	@echo "🍎 Updating CocoaPods dependencies..."
	@cd ios && pod update
	@echo "✅ Pods updated"

# ─── Device Utilities ─────────────────────────────────────────────────────────

devices:
	@flutter devices

# Open Android project in Android Studio
open-android:
	@echo "🤖 Opening Android project in Android Studio..."
	@open -a "Android Studio" android/

# Open iOS project in Xcode
open-ios:
	@echo "🍎 Opening iOS project in Xcode..."
	@open ios/Runner.xcworkspace

# ─── Notification testing ─────────────────────────────────────────────────────

# Trigger a test notification immediately on Android emulator:
#   make test-notification-android
test-notification-android:
	@echo "🔔 Triggering test notification on Android..."
	@adb shell am broadcast -a kg.teitcorp.namaztime.TEST_NOTIFICATION || \
	  echo "ℹ️  No broadcast receiver registered — test via the app's debug screen instead"

# ─── Cleanup ──────────────────────────────────────────────────────────────────

clean:
	@echo "🧹 Cleaning build artifacts..."
	@flutter clean
	@echo "✅ Clean complete"

clean-hive:
	@echo "⚠️  Clearing Hive data (app storage) on Android emulator..."
	@adb shell pm clear $(APP_ID_ANDROID) && \
	  echo "✅ App data cleared" || \
	  echo "❌ No Android emulator/device found — reinstall the app manually on iOS"

# ─── Knowledge Graph ──────────────────────────────────────────────────────────

graphify:
	@echo "🧠 Rebuilding knowledge graph..."
	@graphify update .
	@echo "✅ Graph updated — see graphify-out/GRAPH_REPORT.md"

graphify-report:
	@cat graphify-out/GRAPH_REPORT.md | head -80

# ─── Help ─────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║              NamazTime — Makefile Commands               ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "  Development:"
	@echo "    make run                  Run app in debug mode"
	@echo "    make run-release          Run app in release mode"
	@echo "    make run-profile          Run app in profile mode (perf tracing)"
	@echo "    make run-device DEVICE_ID=<id>"
	@echo "                              Run on a specific device"
	@echo "    make devices              List connected devices"
	@echo ""
	@echo "  Android Builds:"
	@echo "    make build-apk            Build release APK"
	@echo "    make build-apk-debug      Build debug APK"
	@echo "    make build-aab            Build release App Bundle (Play Store)"
	@echo ""
	@echo "  iOS Builds:"
	@echo "    make build-ios            Build release IPA"
	@echo "    make upload-ios           Build IPA and open in Transporter"
	@echo "    make pods-install         Install CocoaPods dependencies"
	@echo "    make pods-update          Update CocoaPods dependencies"
	@echo ""
	@echo "  Assets & Generation:"
	@echo "    make generate-icons       Regenerate launcher icons (assets/icon.png)"
	@echo "    make generate-locales     Validate ru / ky / en translation JSON files"
	@echo "    make translations-diff    Check key parity across all locale files"
	@echo ""
	@echo "  Knowledge Graph:"
	@echo "    make graphify             Rebuild the codebase knowledge graph"
	@echo "    make graphify-report      Print top of GRAPH_REPORT.md"
	@echo ""
	@echo "  Code Quality:"
	@echo "    make analyze              Run flutter analyze"
	@echo "    make format               Auto-format lib/ with dart format"
	@echo "    make format-check         Check formatting without changes"
	@echo "    make test                 Run flutter tests"
	@echo "    make test-coverage        Run tests + generate lcov coverage"
	@echo ""
	@echo "  Utilities:"
	@echo "    make open-android         Open Android project in Android Studio"
	@echo "    make open-ios             Open iOS project in Xcode"
	@echo "    make test-notification-android"
	@echo "                              Send a test notification broadcast (Android)"
	@echo "    make clean                Clean build artifacts"
	@echo "    make clean-hive           Clear Hive app data on Android emulator"
	@echo ""
	@echo "  Android package: $(APP_ID_ANDROID)"
	@echo ""

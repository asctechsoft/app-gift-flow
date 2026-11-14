# CLAUDE.md

Guidance for Claude Code in this folder (Flutter app `gift_flow`, GiftFlow AI). Same ASC base
and build tooling as `music_asc/muvik`.

## Commands

```bash
flutter pub get
flutter run --flavor dev --dart-define=API_BASE_URL=http://10.0.2.2:3000   # flavor required: alpha | dev | product | claude
flutter analyze
flutter test
python build.py                   # APK menu: version bump, release notes, distribute
python build.py dev release       # or flavor + build type directly
python tool/build/build_aab.py    # Play Store bundle (product release)
python tool/check_strings.py      # fail if a used key has no string in values/ or values-vi/
```

## Architecture
GetX + sqflite (local-first, outbox sync) + `asc_common` (path `../../asc_common`). Layers:
`presentation/` -> `controller/` -> `services/` -> `repository/` -> `services/storage/`.
Strings are XML (`lib/xml_strings/values{,-vi}`), used as `'key'.tr`. Flavors are read through
`AppFigs` (`configs/app_figs.dart`), never `appFlavor` directly. Backend: `../backend`.

## Local files (git-ignored, create them yourself)
- `android/app/google-services.json` - Firebase project `app-gift-flow`; the build fails without it.
- `android/key.properties` - only for store signing; without it release is debug-signed.
- `tool/build/build_secrets.json`, `build_auth.json` - optional notification / App Distribution secrets.

Never commit keystores, passwords, tokens or service accounts. API keys live only on the backend.

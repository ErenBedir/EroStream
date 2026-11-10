# Development

## Tools

| Tool | Version | Notes |
|---|---|---|
| Flutter | stable, 3.32+ | `flutter doctor` must be clean for the targets you build |
| Android Studio | current | Android SDK, platform-tools, an emulator image |
| JDK | 17 | bundled with Android Studio |
| Chrome | current | web target |

Windows: install Flutter and Android Studio, then `flutter doctor --android-licenses`.

## First run

```sh
git clone https://github.com/ErenBedir/EroStream
cd EroStream
cp env.example.json env.json
flutter pub get
```

`env.json`:

```json
{ "TG_API_ID": 123456, "TG_API_HASH": "0123456789abcdef0123456789abcdef", "TMDB_KEY": "" }
```

`env.json` is git-ignored. Without it the app asks for the Telegram API ID on first sign-in.

### TDLib

```sh
tool/fetch_tdlib.sh android web                                   # macOS / Linux / Git Bash
powershell -ExecutionPolicy Bypass -File tool\fetch_tdlib.ps1    # Windows
```

Downloads the release named in `tool/tdlib.lock` into `android/app/src/main/jniLibs/` and `web/`.
The release is produced by the `tdlib` workflow (Actions → tdlib → Run workflow).

## Android phone

1. Phone: Settings → About → tap Build number 7× → Developer options → USB debugging on.
2. Connect with USB, accept the prompt on the phone.
3. `flutter devices` lists it.
4. `flutter run --dart-define-from-file=env.json`

Wireless: Developer options → Wireless debugging → pair, then `adb pair` / `adb connect`.

## Android TV

Emulator: Android Studio → Device Manager → Create device → TV → 1080p → system image API 34.
Real TV / box: enable Developer options and network debugging, then `adb connect <tv-ip>:5555`.
Arrow keys and Enter on the keyboard map to the remote.

## Web

```sh
flutter run -d chrome --dart-define-from-file=env.json
```

Without tdweb files in `web/` the app runs, Telegram shows as unavailable.

## Checks

```sh
flutter analyze
flutter test
```

`test/fixtures/golden.json` holds reference outputs for the file name parser and title
matching; keep it in sync when parser rules change.

## Release builds

```sh
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
flutter build web --release --dart-define-from-file=env.json
```

CI reads `TG_API_ID`, `TG_API_HASH`, `TMDB_KEY` from repository secrets.

## Publishing a release

1. Bump `version:` in `pubspec.yaml`, update `docs/release-notes.md`, merge to `main`.
2. `git push origin main:release`
3. The `release` workflow builds split APKs + web zip and publishes `v<version>`.

Signing secrets (optional, without them APKs use the CI debug key and can't be updated in place):
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

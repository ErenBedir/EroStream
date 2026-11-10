# EroStream

Media library and player for files on your device and Telegram channels / topic groups.
No server. Everything runs on the device: your Telegram account, your storage, your bandwidth.

> Status: early development (M2). Sign-in, Telegram scanning, TMDB matching and native playback work; web playback and local folders are next.
> See [docs/PLAN.md](docs/PLAN.md).

## What it does

- Sign in with your own Telegram account (QR or phone + code + 2FA). TDLib runs inside the app.
- Create libraries (Movies, Series, Mixed) and add sources:
  - Telegram channel: titles are parsed from file names.
  - Telegram group with topics: topic title = series name, file name = season/episode. Per-topic rules (series / movie / from file name / skip).
  - Local folder.
- Matches titles to TMDB (posters, overview, seasons). Low-confidence matches go to a review list instead of being guessed.
- Streams Telegram files directly: the player reads byte ranges, TDLib downloads only those parts.

No content, channel list or account is shipped with the app. You decide what to add.

## Platforms

| Platform | Telegram engine | Player | State |
|---|---|---|---|
| Android, Android TV | TDLib (FFI) | mpv (media_kit) | first target |
| Web (PWA) | tdweb (WebAssembly) | browser video | in progress |
| Windows, Linux, macOS | TDLib (FFI) | mpv | later |
| iOS | TDLib (FFI) | mpv | later |

## Build

Requirements: Flutter stable (3.32+), Android SDK for Android builds.

```sh
git clone https://github.com/ErenBedir/EroStream
cd EroStream
cp env.example.json env.json          # fill in TG_API_ID / TG_API_HASH / TMDB_KEY
flutter pub get
tool/fetch_tdlib.sh android web       # prebuilt TDLib from this repo's releases
flutter run --dart-define-from-file=env.json
```

Details, emulator / TV setup and web: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

### API keys

- **Telegram**: create an app at [my.telegram.org](https://my.telegram.org) → API development tools.
  If you publish a fork, use your own `api_id`. Users can also enter their own in Settings.
- **TMDB**: v3 API key or v4 read access token from [themoviedb.org](https://www.themoviedb.org/settings/api).
  Optional at build time; can be set in Settings.

## Configuration

Everything has a default and can be changed at runtime:

| Setting | Build time (`env.json`) | Runtime |
|---|---|---|
| Telegram API ID / hash | `TG_API_ID`, `TG_API_HASH` | Settings → Telegram API credentials |
| TMDB key | `TMDB_KEY` | Settings → TMDB API key |
| Metadata language | UI language | Settings → Metadata language (`tr-TR`, `en-US`, ...) |
| UI language | system | Settings → Language |
| Telegram cache limit | 2 GB | Settings → Storage |

## Languages

English and Turkish. Adding a language = one ARB file, see [docs/TRANSLATING.md](docs/TRANSLATING.md).

## Docs

- [docs/PLAN.md](docs/PLAN.md) – scope and milestones
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) – modules, streaming, matching
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) – local setup and testing
- [docs/TRANSLATING.md](docs/TRANSLATING.md) – adding a language
- [CONTRIBUTING.md](CONTRIBUTING.md)

## License

MIT. Third-party: TDLib (BSL-1.0), media_kit (MIT), libmpv (LGPL-2.1+).

This product uses the TMDB API but is not endorsed or certified by TMDB.

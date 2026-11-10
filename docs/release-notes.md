First public build. Early development: expect rough edges.

## Included

- Telegram sign-in (QR, phone + code, 2FA). TDLib runs inside the app, no server.
- Libraries with Telegram channels and topic groups (per-topic rules: series / movie / from file name / skip).
- Incremental scanning, TMDB matching with a review list and manual fix.
- Player (mpv): resume, next episode, audio/subtitle tracks, TV remote keys.
- Home with backdrop hero, continue watching, recently added; detail page with seasons and episodes.
- English and Turkish UI.

## Not yet

- Playback on web (UI and scanning work, playback says unsupported).
- Local folders.

## Files

| File | For |
|---|---|
| `EroStream-<version>-arm64-v8a.apk` | most Android phones, TVs and boxes |
| `EroStream-<version>-armeabi-v7a.apk` | older / 32-bit devices |
| `EroStream-<version>-x86_64.apk` | emulators |
| `EroStream-<version>-web.zip` | static web build, serve from any web server |

Telegram API ID / hash: enter in Settings if the build asks for it (my.telegram.org).
Posters need a TMDB key (Settings → TMDB API key).

This product uses the TMDB API but is not endorsed or certified by TMDB.

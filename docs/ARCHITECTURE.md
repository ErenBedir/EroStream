# Architecture

```
Flutter app
 ├─ telegram/     TDLib JSON client (FFI on native, tdweb on web), sign-in, chats, topics
 ├─ stream/       (M2) loopback HTTP range server → player
 ├─ library/      library + source config, item store, scanner
 ├─ media/        file name parser, version labels
 ├─ metadata/     TMDB client, title candidates, scoring
 ├─ features/     screens
 ├─ ui/           design tokens, theme, shared widgets
 └─ l10n/         ARB files (generated code in l10n/gen, not committed)
```

## Telegram

`TdTransport` is the only platform-specific piece:

| Target | Transport | Binary |
|---|---|---|
| Android / desktop / iOS | `td_transport_native.dart`: `td_create_client_id`, `td_send`, `td_receive` (own isolate), `td_execute` | `libtdjson` from `tool/fetch_tdlib.*` |
| Web | `td_transport_web.dart` → `web/td_bridge.js` → tdweb `TdClient` | `tdweb.js` + worker + wasm next to `index.html` |

Both speak the same TDLib JSON API, so `TdClient` (request/response by `@extra`) and
`TelegramService` (auth state machine, chats, topics) are shared.

`EROSTREAM_TDJSON=/path/to/libtdjson.so` overrides the library path on desktop.

## Streaming (M2)

Native:

```
mpv ── GET /f/<file_id> Range: bytes=a-b ──▶ 127.0.0.1:<port>
        downloadFile(file_id, priority, offset=a, limit=chunk)
        wait until getFileDownloadedPrefixSize(offset=a) covers the chunk
        read from local.path at offset a (sparse file), write to response
```

Seeking and MKV cue reads at the end of the file are plain range requests.
Cache size is enforced with `optimizeStorage` against the limit in Settings.

Web: a service worker answers range requests for `/f/<file_id>` and asks the page
(tdweb `readFilePart`) for the bytes. The browser's `<video>` element plays the result.

## Library

Library definitions (`library/models.dart`) are small JSON kept in preferences.
Unknown source types are preserved, so newer versions or forks can add source types
without breaking older configs.

Scanned items (M3) go to SQLite: one row per file (source key, message/file id, size,
parsed name, TMDB id, season/episode, version label). Sync cursor per source:
`TelegramSource.lastMessageId`.

## Source types

| Type | Config | Notes |
|---|---|---|
| `telegram` | `chat_id`, `forum`, `topics{id: {mode, name}}` | channels, supergroups, topic groups |
| `local` | `path` | file path, or `content://` tree URI on Android |

A new source type needs: a `SourceConfig` subclass, a scanner that yields files, and a
stream opener. Nothing else depends on the source type.

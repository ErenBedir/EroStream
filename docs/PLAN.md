# Plan

Simpler, calmer spin-off of the EroFlix stack. No server, no Jellyfin, no user accounts.
One app, the user's own Telegram account, the user's own device and connection.

## Scope (v1)

In:

1. Telegram sign-in (QR, phone + code, 2FA password). Session stays on the device.
2. Libraries with multiple sources each: local folder, Telegram channel, Telegram topic group.
3. Topic rules per topic: auto / series / movie / from file name / skip, optional series name override.
4. Incremental sync: only messages after the last seen id. Runs on open and on manual refresh. No background daemon.
5. TMDB matching with a review queue for weak matches. Manual fixes are kept across syncs.
6. Player: resume, next episode, audio/subtitle tracks, `.srt` files from the same topic as subtitles,
   alternative versions of the same episode with quality labels.
7. Screens: home (continue watching, recently added), library grid, detail, player, sources, review queue, settings.
8. UI languages from ARB files (en, tr). Web build.

Out (v1): user accounts, server, comments, live TV, recommendations, cloud sync.

## Milestones

| # | Work | Done when |
|---|---|---|
| M0 | Skeleton, design tokens, theme, l10n, CI | app builds on every target in CI |
| M1 | TDLib sign-in, chat and topic picker, library config | account connects, sources can be chosen |
| M2 | Streaming bridge: TDLib → loopback HTTP range server → mpv. Web: service worker → tdweb `readFilePart` | a Telegram file plays and seeks |
| M3 | Scanner, parser, TMDB matcher, item store (SQLite) | posters, seasons, episodes |
| M4 | Local folder source (SAF on Android, File System Access on web) | |
| M5 | UI polish, TV remote navigation, desktop | |
| M6 | Docs, contribution guide, release builds | public v0.1 |

M2 is the riskiest part and comes before the library UI on purpose.

## Risks

- TDLib is ~20–30 MB per ABI. APKs are split per ABI.
- tdweb needs emsdk 3.1.1; its build is slow and pinned in `tool/tdlib.lock`.
- Browsers can't play every container/codec (MKV/HEVC). Web plays what the browser supports and says so.
- iOS limits background downloads.

## Matching pipeline

1. File name → parser (`lib/media/name_parser.dart`). Topic title = series name in topic groups.
2. Search candidates (`lib/metadata/title_match.dart`): bilingual titles split, platform tags removed, year extracted.
3. TMDB search with year, then without; UI language first.
4. Score = best similarity against local and original title, ± year, popularity as tie-breaker.
   `>= 0.82` applied automatically, lower goes to the review queue with the top 3 candidates.
5. A matched topic / folder is locked to its TMDB id; every episode inherits it.

# Translating

UI strings live in `lib/l10n/app_<code>.arb`. `app_en.arb` is the template.

## Add a language

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb` (`de`, `ar`, `pt_BR`, ...).
2. Set `"@@locale": "<code>"`.
3. Translate the values. Keep the keys and `{placeholders}` as they are. Skip `@key` metadata entries.
4. Set `languageName` to the language's own name (`Deutsch`, `العربية`).
5. `flutter pub get` regenerates `lib/l10n/gen/`. The language shows up in Settings → Language automatically.

Missing keys fall back to English at build time with a warning listed by `flutter gen-l10n`.

## Rules

- Short, plain, technical. No exclamation marks.
- Plurals use ICU syntax: `{count, plural, =1{1 topic} other{{count} topics}}`.
- Metadata language (TMDB) is separate from the UI language and set in Settings.

# Contributing

## Before a PR

- `flutter analyze` without errors, `flutter test` green.
- One topic per PR. Title in imperative, short: `Parser: handle "S01 BL02"`.
- Description: what changed and why, as bullet points. Mention how it was tested (device / emulator / web).
- UI changes: screenshot or short recording.

## Code

- Dart style from `analysis_options.yaml`. Single quotes.
- No new dependency without a reason in the PR description. Prefer small, maintained, pure-Dart packages.
- Strings go to ARB files, never hard-coded in widgets.
- Platform code stays behind an interface (see `TdTransport`).

## Content

The project ships no channels, links or content lists and won't accept PRs that add them.

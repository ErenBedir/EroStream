#!/usr/bin/env bash
# Downloads prebuilt TDLib for the given targets (android, web) from this repo's releases.
# Usage: tool/fetch_tdlib.sh [android] [web]
set -euo pipefail
cd "$(dirname "$0")/.."
source <(grep -v '^#' tool/tdlib.lock)
REPO="${EROSTREAM_REPO:-ErenBedir/EroStream}"
BASE="https://github.com/$REPO/releases/download/$TDLIB_TAG"
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(android web)
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for t in "${targets[@]}"; do
  echo "tdlib $TDLIB_TAG: $t"
  curl -fsSL "$BASE/tdlib-$t.tar.gz" -o "$tmp/$t.tar.gz"
  case "$t" in
    android)
      rm -rf android/app/src/main/jniLibs
      mkdir -p android/app/src/main
      tar -xzf "$tmp/$t.tar.gz" -C android/app/src/main
      find android/app/src/main/jniLibs -name '*.so' ;;
    web)
      tar -xzf "$tmp/$t.tar.gz" -C web
      ls web | grep -E 'tdweb|worker|wasm' ;;
    *) echo "unknown target $t" >&2; exit 1 ;;
  esac
done

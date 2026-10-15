#!/usr/bin/env bash
# Download every file in sources.txt into sources/ and check its SHA-256.
# A file already there is checked, not downloaded again. Any mismatch fails.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
dest=${SOURCES_DIR:-$root/sources}
mkdir -p "$dest"
ua='ffmpeg-builds (+https://github.com/wallpaper-reactor/ffmpeg-builds)'

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

grep -v '^#' "$root/sources.txt" | while read -r name file url sum; do
  [ -n "$name" ] || continue
  if [ ! -f "$dest/$file" ]; then
    echo "fetch $file"
    curl -fsSL --retry 3 -A "$ua" -o "$dest/$file.part" "$url"
    mv "$dest/$file.part" "$dest/$file"
  fi
  got=$(sha256 "$dest/$file")
  if [ "$got" != "$sum" ]; then
    echo "checksum mismatch for $file: expected $sum, got $got" >&2
    exit 1
  fi
  echo "ok    $file"
done

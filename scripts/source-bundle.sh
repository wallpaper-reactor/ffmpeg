#!/usr/bin/env bash
# The corresponding source for a release: the verified upstream tarballs (and
# FFmpeg's signature) plus this repository's files, as one tar.
#   scripts/source-bundle.sh   ->  dist/ffmpeg-<version>-<build>-source.tar
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/version.env"
cd "$root"
scripts/fetch-sources.sh >/dev/null
name=ffmpeg-$FFMPEG_VERSION-$BUILD-source
mkdir -p dist
files=$(git ls-files)
list=$(grep -v '^#' sources.txt | awk 'NF {print "sources/" $2}')
# shellcheck disable=SC2086
tar -cf "dist/$name.tar" --transform "s|^|$name/|" $files $list
ls -l "dist/$name.tar"

#!/usr/bin/env bash
# Build Linux and Windows targets the way CI does, inside ubuntu:22.04.
#   scripts/docker-build.sh linux-x86_64 [linux-aarch64 windows-x86_64 ...]
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
docker run --rm -v "$root:/b" -w /b -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" ubuntu:22.04 bash -c '
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq >/dev/null
  apt-get install -y -qq build-essential nasm pkg-config zip unzip xz-utils bzip2 \
    gcc-aarch64-linux-gnu gcc-mingw-w64-x86-64 >/dev/null
  status=0
  for t in "$@"; do scripts/build.sh "$t" || status=1; done
  chown -R "$HOST_UID:$HOST_GID" work dist
  exit $status
' sh "$@"

#!/usr/bin/env bash
# Run a built archive through every way `wr` calls ffmpeg and ffprobe.
#   scripts/smoke-test.sh dist/ffmpeg-<version>-<target>.zip
set -euo pipefail
zipfile=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
t=$(mktemp -d)
cd "$t"
mkdir bin; if command -v unzip >/dev/null; then unzip -q "$zipfile" -d bin; else tar -xf "$zipfile" -C bin; fi
exe=""; [ -f bin/ffmpeg.exe ] && exe=.exe
ff=./bin/ffmpeg$exe; fp=./bin/ffprobe$exe
"$ff" -hide_banner -version | head -1
"$ff" -hide_banner -encoders 2>/dev/null | grep -q libx264 || { echo "no libx264 encoder" >&2; exit 1; }

# 24 frames of 64x64 noise as raw RGB, written out as a PNG sequence.
head -c $((64*64*3*24)) /dev/urandom > noise.rgb
mkdir frames
"$ff" -v error -y -f rawvideo -pix_fmt rgb24 -s 64x64 -framerate 24 -i noise.rgb frames/frame%08d.png
[ -f frames/frame00000023.png ] || [ -f frames/frame00000024.png ] || { echo "png sequence not written" >&2; exit 1; }
first=0; [ -f frames/frame00000000.png ] || first=1

# wr's encode: PNG sequence -> H.264 MP4.
"$ff" -v error -y -framerate 24 -start_number $first -i frames/frame%08d.png -frames:v 24 \
  -c:v libx264 -pix_fmt yuv420p -crf 23 -preset slow -movflags +faststart out.mp4
# wr's probe.
"$fp" -v error -select_streams v:0 -show_entries stream=nb_frames,width,height,duration -of json out.mp4 > probe.json
grep -q '"nb_frames": "24"' probe.json || { cat probe.json; echo "unexpected probe" >&2; exit 1; }
# wr's decodes: MP4 -> RGB grid; PNG sequence -> sampled grey.
n=$("$ff" -v error -i out.mp4 -vf scale=16:16:flags=area -f rawvideo -pix_fmt rgb24 - | wc -c)
[ "$n" -eq $((16*16*3*24)) ] || { echo "grid decode gave $n bytes" >&2; exit 1; }
n=$("$ff" -v error -framerate 24 -start_number $first -i frames/frame%08d.png -vf fps=12,scale=32:32:flags=area -f rawvideo -pix_fmt gray - | wc -c)
[ "$n" -eq $((32*32*12)) ] || { echo "luma decode gave $n bytes" >&2; exit 1; }
echo "smoke test passed: $(basename "$zipfile")"

#!/usr/bin/env bash
# Build a static, GPL ffmpeg + ffprobe with libx264 for one target, from the
# verified tarballs in sources/. Output: dist/ffmpeg-<version>-<target>.zip
#
#   scripts/build.sh linux-x86_64 | linux-aarch64 | windows-x86_64 | macos-arm64 | macos-x86_64
#
# Only what Wallpaper Reactor's `wr` uses is enabled: H.264 encoding (libx264)
# into MP4, PNG sequences in and out, raw video out, and ffprobe.
set -euo pipefail
target=${1:?usage: build.sh <target>}
root=$(cd "$(dirname "$0")/.." && pwd)
src=${SOURCES_DIR:-$root/sources}
work=${WORK_DIR:-$root/work/$target}
dist=$root/dist
. "$root/version.env"
jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)

prefix=$work/prefix
mkdir -p "$work" "$prefix" "$dist"

cross=""; exe=""; ldflags=""; cflags="-O2"; ffos=""; ffarch=""; threads=--enable-pthreads; cc=cc
case "$target" in
  linux-x86_64)
    ffos=linux; ffarch=x86_64; ldflags="-static"
    [ "$(uname -m)" = x86_64 ] || cross=x86_64-linux-gnu- ;;
  linux-aarch64)
    ffos=linux; ffarch=aarch64; ldflags="-static"
    [ "$(uname -m)" = aarch64 ] || cross=aarch64-linux-gnu- ;;
  windows-x86_64)
    ffos=mingw32; ffarch=x86_64; ldflags="-static"; exe=.exe; threads=--enable-w32threads
    cross=x86_64-w64-mingw32- ;;
  macos-arm64)
    ffos=darwin; ffarch=aarch64; cc="clang -arch arm64"
    cflags="$cflags -mmacosx-version-min=11.0"; ldflags="-mmacosx-version-min=11.0" ;;
  macos-x86_64)
    ffos=darwin; ffarch=x86_64; cc="clang -arch x86_64"
    cflags="$cflags -mmacosx-version-min=10.15"; ldflags="-mmacosx-version-min=10.15" ;;
  *) echo "unknown target $target" >&2; exit 2 ;;
esac
[ -n "$cross" ] && cc=${cross}gcc
case "$target" in
  macos-arm64)  host=aarch64-apple-darwin; [ "$(uname -m)" = arm64 ] || iscross=1 ;;
  macos-x86_64) host=x86_64-apple-darwin;  [ "$(uname -m)" = x86_64 ] || iscross=1 ;;
  *) host=${cross%-} ;;
esac

unpack() { rm_dir "$work/$2"; mkdir -p "$work/$2"; tar -xf "$src/$1" -C "$work/$2" --strip-components=1; }
# Remove a directory this script made under $work, and nothing else.
rm_dir() { case "$1" in "$work"/*) [ -d "$1" ] && find "$1" -mindepth 1 -delete && rmdir "$1" || true ;; *) echo "refusing to remove $1" >&2; exit 3 ;; esac; }

echo "== zlib $ZLIB_VERSION"
unpack "zlib-$ZLIB_VERSION.tar.gz" zlib
(cd "$work/zlib"
 if [ "$ffos" = mingw32 ]; then
   make -f win32/Makefile.gcc PREFIX="$cross" CFLAGS="$cflags" -j"$jobs" libz.a
   mkdir -p "$prefix/lib" "$prefix/include"; cp libz.a "$prefix/lib/"; cp zlib.h zconf.h "$prefix/include/"
 else
   CC="$cc" CFLAGS="$cflags" ./configure --static --prefix="$prefix" >/dev/null
   make -j"$jobs" install >/dev/null
 fi)

echo "== x264 $X264_COMMIT"
unpack "x264-$X264_COMMIT.tar.bz2" x264
x264_host=(); [ -n "$cross" ] && x264_host=(--host="$host" --cross-prefix="$cross")
[ -n "${iscross:-}" ] && x264_host=(--host="$host")
(cd "$work/x264"
 CC="$cc" ./configure --prefix="$prefix" ${x264_host[@]+"${x264_host[@]}"} --enable-static --enable-pic --disable-cli \
   --bit-depth=8 --chroma-format=420 --disable-opencl --disable-avs --disable-swscale --disable-lavf \
   --disable-ffms --disable-gpac --disable-lsmash \
   --extra-cflags="$cflags" --extra-ldflags="$ldflags" >/dev/null
 make -j"$jobs" >/dev/null && make install-lib-static >/dev/null)

echo "== ffmpeg $FFMPEG_VERSION"
unpack "ffmpeg-$FFMPEG_VERSION.tar.xz" ffmpeg
ffcross=(); [ -n "$cross" ] && ffcross=(--enable-cross-compile --cross-prefix="$cross")
[ -n "${iscross:-}" ] && ffcross=(--enable-cross-compile)
configure=(
  --prefix="$prefix" --target-os="$ffos" --arch="$ffarch" ${ffcross[@]+"${ffcross[@]}"} --cc="$cc"
  --pkg-config=pkg-config --pkg-config-flags=--static
  --extra-cflags="$cflags -I$prefix/include" --extra-ldflags="$ldflags -L$prefix/lib"
  --enable-gpl --enable-libx264 --enable-zlib "$threads"
  --disable-autodetect --disable-everything --disable-debug --disable-doc --disable-ffplay
  --disable-network --disable-avdevice --disable-swresample --disable-shared --enable-static
  --enable-protocol=file,pipe
  --enable-demuxer=image2,mov,rawvideo
  --enable-muxer=mp4,mov,image2,rawvideo
  --enable-decoder=png,h264,rawvideo
  --enable-encoder=libx264,png,rawvideo
  --enable-parser=h264,png
  --enable-filter=scale,fps,format,null,setpts
)
(cd "$work/ffmpeg"
 PKG_CONFIG_PATH="$prefix/lib/pkgconfig" PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig" ./configure "${configure[@]}" > "$work/configure.log" || { tail -40 ffbuild/config.log; exit 1; }
 make -j"$jobs" >/dev/null
 ${cross}strip ffmpeg$exe ffprobe$exe 2>/dev/null || strip ffmpeg$exe ffprobe$exe)

name=ffmpeg-$FFMPEG_VERSION-$BUILD-$target
stage=$work/$name
rm_dir "$stage"; mkdir -p "$stage"
cp "$work/ffmpeg/ffmpeg$exe" "$work/ffmpeg/ffprobe$exe" "$stage/"
tar -xOf "$src/ffmpeg-$FFMPEG_VERSION.tar.xz" "ffmpeg-$FFMPEG_VERSION/COPYING.GPLv2" > "$stage/COPYING.GPLv2"
{
  echo "FFmpeg $FFMPEG_VERSION with x264 ($X264_COMMIT) and zlib $ZLIB_VERSION, built by"
  echo "https://github.com/wallpaper-reactor/ffmpeg ($BUILD, target $target)."
  echo
  echo "Licence: GPL-2.0-or-later (FFmpeg built with --enable-gpl, x264 is GPL-2.0-or-later,"
  echo "zlib is under the zlib licence). No nonfree components. See COPYING.GPLv2."
  echo
  echo "Corresponding source: the release this archive came from carries"
  echo "ffmpeg-$FFMPEG_VERSION-$BUILD-source.tar, holding the exact upstream tarballs and the"
  echo "scripts that built this archive:"
  echo "https://github.com/wallpaper-reactor/ffmpeg/releases/tag/$FFMPEG_VERSION-$BUILD"
  echo
  echo "configure: ${configure[*]}" | sed "s|$root|.|g"
} > "$stage/SOURCE.txt"
rm -f "$dist/$name.zip"
(cd "$stage" && zip -q -X -9 "$dist/$name.zip" ffmpeg$exe ffprobe$exe COPYING.GPLv2 SOURCE.txt)
ls -l "$dist/$name.zip"

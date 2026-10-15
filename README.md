# ffmpeg-builds

Small static builds of FFmpeg with x264, made for
[Wallpaper Reactor](https://wallpaperreactor.app)'s `wr` command line tool, which downloads
one on first use to encode and check wallpaper videos.

Each [release](https://github.com/wallpaper-reactor/ffmpeg-builds/releases) carries, for
Windows x64, Linux x64 and arm64, and macOS arm64 and x86_64:

- `ffmpeg-<version>-<build>-<target>.zip`: `ffmpeg`, `ffprobe`, `COPYING.GPLv2` and
  `SOURCE.txt` (what was built, the exact `configure` line, and where the source is).
- `ffmpeg-<version>-<build>-source.tar`: the corresponding source. The exact upstream
  tarballs (plus FFmpeg's signature) and this repository's scripts.
- `SHA256SUMS` for all of the above.

## What is in a build

Only what `wr` uses, so each archive is about 4 to 5 MB:

| Part | Enabled |
| --- | --- |
| Encoders | `libx264` (H.264), `png`, `rawvideo` |
| Decoders | `h264`, `png`, `rawvideo` |
| Containers | MP4/MOV in and out, image sequences (`image2`), raw video |
| Filters | `scale`, `fps`, `format`, `null`, `setpts`, plus what the `ffmpeg` tool needs |
| Protocols | `file`, `pipe` |
| Programs | `ffmpeg`, `ffprobe` (no `ffplay`) |

No network protocols, no devices, no hardware acceleration, no audio resampling, and no
auto-detected system libraries. Linux and Windows binaries are fully static; macOS
binaries link only system frameworks (macOS 11+ on arm64, 10.15+ on x86_64).

Sources (pinned in [`sources.txt`](sources.txt), versions in [`version.env`](version.env)):

- FFmpeg 9.0.2, from ffmpeg.org
- x264, the `stable` branch at `b35605ace3ddf7c1a5d67a2eb553f034aef41d55`, from code.videolan.org
- zlib 1.3.1 (for PNG), from zlib.net

## Licence

The builds are **GPL-2.0-or-later**: FFmpeg is configured with `--enable-gpl` to link x264,
which is GPL-2.0-or-later. zlib is under the zlib licence. Nothing is built with
`--enable-nonfree`, so the binaries are redistributable. The source for every binary is
attached to the release it came from.

The scripts in this repository are GPL-3.0-or-later ([`COPYING`](COPYING)).

## Reproduce a build

```sh
scripts/fetch-sources.sh            # download into sources/ and check every SHA-256
scripts/build.sh linux-x86_64       # or linux-aarch64, windows-x86_64, macos-arm64, macos-x86_64
scripts/smoke-test.sh dist/ffmpeg-*-linux-x86_64.zip
```

Linux and Windows targets build on Ubuntu 22.04 with `build-essential nasm pkg-config zip`,
plus `gcc-aarch64-linux-gnu` or `gcc-mingw-w64-x86-64` to cross-compile;
`scripts/docker-build.sh <targets…>` does that in a container. macOS targets need the
Xcode command line tools, `nasm` and `pkg-config`; both macOS targets build on Apple silicon.

The smoke test runs each archive through what `wr` does with it: a PNG sequence encoded to
H.264 MP4, `ffprobe` reading it back, and both decoded to raw frames.

## Releases

[`.github/workflows/build.yml`](.github/workflows/build.yml) builds and tests every target
on each push. Pushing a tag `<version>-<build>` (matching `version.env`, for example
`9.0.2-wr1`) also publishes the release with its source and checksums.

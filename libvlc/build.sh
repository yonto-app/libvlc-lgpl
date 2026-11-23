#!/bin/sh
# Builds the libVLC the Android apps ship, from VideoLAN's own sources with every GPL library left out (no x264,
# x265, libdvdread or live555; FFmpeg without --enable-gpl), so the engine is LGPL-2.1 and nothing else
# (docs/design/2026-10-04-files-and-network-libraries.md), plus ../vlc/'s patches, which both libVLC builds apply
# (FFmpeg's AVS+ decoder, a decoder made while paused told of the pause, and a subtitle file given an ES id no other
# track holds, without which one beside a WMV could never be selected), and vlc/'s, which only this one does
# (VideoLAN's fix that keeps a refused DynamicsProcessing from silencing the AudioTrack, until libvlcjni's VLC carries it).
# Writes a Maven repository holding the AAR: -Pyonto.libvlcRepo=<it> tries it, and what is kept at yonto-app/libvlc-lgpl
# (which settings.gradle.kts pins) is a copy of it.
#
#   tools/libvlc/build.sh [outdir]      outdir defaults to build/libvlc-repo
#
# Needs macOS or Linux with the Android SDK, JDK 17, NDK 28 (arm64-v8a) and NDK 21 (armeabi-v7a; on an Apple Silicon Mac
# it needs Rosetta, its ndk-build needs arm64 added to its x86_64 host case, and its GNU ar, ranlib, nm, strip, objcopy,
# objdump and readelf crash there, so each is swapped for NDK 28's llvm- one, in both toolchains' bin folders), and
# Homebrew's automake libtool pkg-config gettext meson nasm yasm wget gnu-sed bison flex ragel protobuf coreutils, with
# coreutils' and gnu-sed's gnubin first on PATH: libvlcjni checks the Gradle it downloads with GNU sha256sum.
set -eu

VLC_ANDROID_TAG=libvlc-3.6.5
LIBVLCJNI_BRANCH=libvlcjni-3.x
LIBVLCJNI_HASH=965e8648717076654f463ae64ee1d008d7ff282d
VERSION=3.6.5-5
: "${ANDROID_SDK:?set ANDROID_SDK}"
: "${NDK_ARM64:?set NDK_ARM64 to NDK 28}"
: "${NDK_ARMV7:?set NDK_ARMV7 to NDK 21}"

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="${1:-$root/build/libvlc-repo}"
work="${LIBVLC_WORK:-$root/build/libvlc-src}"
mkdir -p "$work"
cd "$work"

[ -d vlc-android ] || git clone --depth 1 --branch "$VLC_ANDROID_TAG" https://code.videolan.org/videolan/vlc-android.git
if [ ! -d libvlcjni ]; then
  git clone --single-branch --branch "$LIBVLCJNI_BRANCH" https://code.videolan.org/videolan/libvlcjni.git
  git -C libvlcjni reset --hard "$LIBVLCJNI_HASH"
  cp "$here"/../vlc/*.patch "$here"/vlc/*.patch libvlcjni/libvlc/patches/
fi

# Homebrew's autoconf adds -std=gnu23, which the K&R C in FLAC and libsmb2 does not compile under.
export ac_cv_prog_cc_c23=no
# protobuf and protobuf-lite are both contribs, and pkg-config calls that a conflict.
export PKG_CONFIG_IGNORE_CONFLICTS=1
export ANDROID_SDK VLC_LIBJNI_PATH="$work/libvlcjni"

# Each patch must be in VLC as it is here, not only by its Message-Id: a work folder cloned before a patch was added or
# changed never copies it again, and libvlcjni's own check reads the Message-Id alone.
check_patches() {
  for patch in "$here"/../vlc/*.patch "$here"/vlc/*.patch; do
    id="$(sed -n 's/^Message-Id: <\(.*\)>$/\1/p' "$patch" | head -n 1)"
    commit="$(git -C "$work/libvlcjni/vlc" log --format=%H --fixed-strings --grep="$id" | head -n 1)"
    if [ -z "$commit" ] || [ "$(git -C "$work/libvlcjni/vlc" -c diff.suppressBlankEmpty=false diff-tree -p "$commit" | git patch-id --stable | cut -d' ' -f1)" != \
        "$(git patch-id --stable < "$patch" | cut -d' ' -f1)" ]; then
      echo "VLC in $work/libvlcjni does not hold $(basename "$patch") as it is now: remove $work/libvlcjni and build again" >&2
      exit 1
    fi
  done
}

compile() {
  ANDROID_NDK="$2" sh -c "cd vlc-android && sh buildsystem/compile.sh -l -a $1 --license a"
}

# A failure here is fatal, a patch that no longer applies included, but for the first build of an ABI: libgcrypt's pkg-config
# file requires a gpg-error.pc that libgpg-error's contrib does not install, which is written and the build run again.
build() {
  abi="$1" ndk="$2" tuple="$3"
  compile "$abi" "$ndk" && return
  prefix="$work/libvlcjni/vlc/contrib/$tuple"
  if [ ! -d "$prefix/lib/pkgconfig" ] || [ -f "$prefix/lib/pkgconfig/gpg-error.pc" ]; then
    echo "$abi did not build" >&2
    exit 1
  fi
  printf 'prefix=%s\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\n\nName: gpg-error\nDescription: GnuPG error library\nVersion: 1.50\nCflags: -I${includedir}\nLibs: -L${libdir} -lgpg-error\n' "$prefix" > "$prefix/lib/pkgconfig/gpg-error.pc"
  compile "$abi" "$ndk"
}
[ -d "$work/libvlcjni/vlc" ] && check_patches
build arm64-v8a "$NDK_ARM64" aarch64-linux-android
build armeabi-v7a "$NDK_ARMV7" arm-linux-androideabi
check_patches

aar="$work/libvlcjni/libvlc/build/outputs/aar/libvlc-dev.aar"
for abi in arm64-v8a armeabi-v7a; do
  if strings -a "$work/libvlcjni/libvlc/jni/libs/$abi/libvlc.so" | grep -q -E 'x264 advanced options|live555\.cpp|modules/access/dvd(read|nav)\.c'; then
    echo "$abi libvlc.so still holds GPL code" >&2
    exit 1
  fi
  if ! strings -a "$work/libvlcjni/libvlc/jni/libs/$abi/libvlc.so" | grep -q 'Enhanced field coded P picture'; then
    echo "$abi libvlc.so has no AVS+ decoder" >&2
    exit 1
  fi
  if ! strings -a "$work/libvlcjni/libvlc/jni/libs/$abi/libvlc.so" | grep -q 'DynamicsProcessing\.%s triggered an exception'; then
    echo "$abi libvlc.so lets a refused DynamicsProcessing silence the AudioTrack" >&2
    exit 1
  fi
done

dir="$out/app/yonto/vendor/libvlc-lgpl/$VERSION"
mkdir -p "$dir"
cp "$aar" "$dir/libvlc-lgpl-$VERSION.aar"
cat > "$dir/libvlc-lgpl-$VERSION.pom" <<POM
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>app.yonto.vendor</groupId>
  <artifactId>libvlc-lgpl</artifactId>
  <version>$VERSION</version>
  <packaging>aar</packaging>
  <licenses><license><name>LGPL-2.1-or-later</name></license></licenses>
</project>
POM
echo "$dir/libvlc-lgpl-$VERSION.aar"

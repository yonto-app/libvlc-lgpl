#!/bin/sh
# Builds the libVLC the Android apps ship, from VideoLAN's own sources with every GPL library left out (no x264,
# x265, libdvdread or live555; FFmpeg without --enable-gpl), so the engine is LGPL-2.1 and nothing else
# (docs/design/2026-10-04-files-and-network-libraries.md). Writes a Maven repository holding the AAR, which
# settings.gradle.kts reads from build/libvlc-repo.
#
#   tools/libvlc/build.sh [outdir]      outdir defaults to build/libvlc-repo
#
# Needs macOS or Linux with the Android SDK, JDK 17, NDK 28 (arm64-v8a) and NDK 21 (armeabi-v7a; on an Apple Silicon Mac
# it needs Rosetta, and its GNU ar and ranlib crash there, so they are swapped for NDK 28's LLVM ones), and
# Homebrew's automake libtool pkg-config gettext meson nasm yasm wget gnu-sed bison flex ragel protobuf coreutils.
set -eu

VLC_ANDROID_TAG=libvlc-3.6.5
LIBVLCJNI_BRANCH=libvlcjni-3.x
LIBVLCJNI_HASH=965e8648717076654f463ae64ee1d008d7ff282d
VERSION=3.6.5-1
: "${ANDROID_SDK:?set ANDROID_SDK}"
: "${NDK_ARM64:?set NDK_ARM64 to NDK 28}"
: "${NDK_ARMV7:?set NDK_ARMV7 to NDK 21}"

root="$(cd "$(dirname "$0")/../.." && pwd)"
out="${1:-$root/build/libvlc-repo}"
work="${LIBVLC_WORK:-$root/build/libvlc-src}"
mkdir -p "$work"
cd "$work"

[ -d vlc-android ] || git clone --depth 1 --branch "$VLC_ANDROID_TAG" https://code.videolan.org/videolan/vlc-android.git
if [ ! -d libvlcjni ]; then
  git clone --single-branch --branch "$LIBVLCJNI_BRANCH" https://code.videolan.org/videolan/libvlcjni.git
  git -C libvlcjni reset --hard "$LIBVLCJNI_HASH"
fi

# Homebrew's autoconf adds -std=gnu23, which the K&R C in FLAC and libsmb2 does not compile under.
export ac_cv_prog_cc_c23=no
# protobuf and protobuf-lite are both contribs, and pkg-config calls that a conflict.
export PKG_CONFIG_IGNORE_CONFLICTS=1
export ANDROID_SDK VLC_LIBJNI_PATH="$work/libvlcjni"

build() {
  abi="$1" ndk="$2" tuple="$3"
  ANDROID_NDK="$ndk" sh -c "cd vlc-android && sh buildsystem/compile.sh -l -a $abi --license a" || true
  # libgcrypt's pkg-config file requires a gpg-error.pc that libgpg-error's contrib does not install.
  prefix="$work/libvlcjni/vlc/contrib/$tuple"
  if [ -d "$prefix/lib/pkgconfig" ] && [ ! -f "$prefix/lib/pkgconfig/gpg-error.pc" ]; then
    printf 'prefix=%s\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\n\nName: gpg-error\nDescription: GnuPG error library\nVersion: 1.50\nCflags: -I${includedir}\nLibs: -L${libdir} -lgpg-error\n' "$prefix" > "$prefix/lib/pkgconfig/gpg-error.pc"
    ANDROID_NDK="$ndk" sh -c "cd vlc-android && sh buildsystem/compile.sh -l -a $abi --license a"
  fi
}
build arm64-v8a "$NDK_ARM64" aarch64-linux-android
build armeabi-v7a "$NDK_ARMV7" arm-linux-androideabi

aar="$work/libvlcjni/libvlc/build/outputs/aar/libvlc-dev.aar"
for abi in arm64-v8a armeabi-v7a; do
  if strings -a "$work/libvlcjni/libvlc/jni/libs/$abi/libvlc.so" | grep -q -E 'x264 advanced options|live555\.cpp|modules/access/dvd(read|nav)\.c'; then
    echo "$abi libvlc.so still holds GPL code" >&2
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

#!/bin/sh
# Builds the libVLC the Windows app ships, for x64: VideoLAN's own VLC sources at the commit tools/libvlc/build.sh's
# libvlcjni pins, cross-compiled with mingw-w64 in the Docker image VLC's own CI builds win64 3.0 in, as
# extras/package/win32/build.sh builds it, plus ../vlc/'s patches, which every libVLC build applies (FFmpeg's AVS+
# decoder, a decoder made while paused told of the pause, and a subtitle file given an ES id no other track holds,
# which 3.0.22-rc1-2 was built before), and ../vlc/desktop/'s, which this and Linux's do (deinterlace
# without Yadif, whose code is FFmpeg's GPL filter, the plugins cache trusted by a plugin's size alone, since an
# MSIX installs every file with the time it was installed, and the format callback offered a picture's visible size, not
# the one its decoder pads it to, which 3.0.22-rc1-2, the one published, was built before) (docs/design/2026-11-17-yonto-on-windows.md).
# Every GPL library is left out as on Android (contribs with --disable-gpl --disable-gnuv3 --enable-ad-clauses, so
# FFmpeg without --enable-gpl, and no x264, x265, a52, dca, faad2, mad, libmpeg2, libdvdread, libdvdnav, libdvdcss,
# live555, GnuTLS or libzvbi), and libbluray kept, so a Blu-ray ISO plays.
# Unlike Android's single libvlc.so, each module is its own DLL, and some of VLC 3's own modules are still GPL (Lua,
# the Real RTSP access and demuxer, the playlist exporters, the file logger, DirectShow and BDA capture): configure
# turns off the ones it can, and every plugin built from a GPL source file is left out of the archive, by a scan of
# the sources each one is made from.
# Writes libvlc-windows-x64-$VERSION.zip (libvlc.dll, libvlccore.dll, plugins/, sdk/ with the headers and import
# libraries, and vlc-cache-gen.exe, which writes plugins/plugins.dat where it is installed: without that cache libVLC
# opens every plugin on each start) into the output folder; what yonto-app/libvlc-lgpl's releases keep is a copy.
#
#   tools/libvlc-windows/build.sh [outdir]      outdir defaults to build/libvlc-windows
#
# Needs Docker able to run linux/amd64 images (on an Apple Silicon Mac, a Colima profile with --vz-rosetta). The build
# tree lives in the Docker volume $LIBVLC_WINDOWS_VOLUME, so a second run resumes where the first stopped.
set -eu

VLC_HASH=c9dde25a62c4612d71250c4eb845154e0ea9e13e
VERSION=3.0.22-rc1-3
IMAGE=registry.videolan.org/vlc-debian-win64:20221023193231
TRIPLET=x86_64-w64-mingw32

here="$(cd "$(dirname "$0")" && pwd)"

if [ "${1:-}" != --inside ]; then
  root="$(cd "$here/../.." && pwd)"
  out="${1:-$root/build/libvlc-windows}"
  mkdir -p "$out"
  out="$(cd "$out" && pwd)"
  volume="${LIBVLC_WINDOWS_VOLUME:-yonto-libvlc-windows}"
  docker volume create "$volume" > /dev/null
  docker run --rm --platform linux/amd64 --user root -v "$volume:/work" "$IMAGE" chown videolan:videolan /work
  exec docker run --rm --platform linux/amd64 -v "$volume:/work" -v "$here/..:/tools:ro" -v "$out:/out" "$IMAGE" \
    sh /tools/libvlc-windows/build.sh --inside
fi

jobs="$(nproc)"
patches="$(printf "%s\n" /tools/vlc/*.patch /tools/vlc/desktop/*.patch)"
vlc=/work/vlc
prefix=/work/install

. /tools/vlc/build-common.sh
clone_vlc "$VLC_HASH"
cd "$vlc"

(cd extras/tools && NEEDED=meson ./bootstrap && make -j"$jobs")
export PATH="$vlc/extras/tools/build/bin:$vlc/contrib/$TRIPLET/bin:$PATH"
export USE_FFMPEG=1

# The flags VLC's win32 build.sh gives a msvcrt release build, whose minimum for VLC 3.0 is Windows XP SP1.
cppflags="-D__MSVCRT_VERSION__=0x700 -D_WIN32_WINNT=0x0502 -DWINVER=0x0502"

mkdir -p contrib/contrib-win64
cd contrib/contrib-win64
printf 'CPPFLAGS := %s\nCFLAGS := %s\nCXXFLAGS := %s\nPKG_CONFIG := pkg-config\nPKG_CONFIG_LIBDIR := /usr/%s/lib/pkgconfig:/usr/lib/%s/pkgconfig\n' \
  "$cppflags" "$cppflags" "$cppflags" "$TRIPLET" "$TRIPLET" > config.mak
# Lua is off below (VLC's Lua module is GPL), so the contrib is too; Qt is VLC's interface, which libVLC has none of;
# asdcplib (digital cinema packages) needs nettle, which is LGPLv3; libzvbi 0.2.35 links GPL-2 files (pdc.c,
# packet-830.c, exp-vtx.c), so teletext is VLC's own telx decoder instead.
../bootstrap --host="$TRIPLET" --prefix="../$TRIPLET" --disable-gpl --disable-gnuv3 --enable-ad-clauses \
  --disable-lua --disable-luac --disable-asdcplib --disable-zvbi --disable-qt --disable-qtsvg --disable-qtdeclarative \
  --disable-qtgraphicaleffects --disable-qtquickcontrols2
make_contribs
cd ../..

refuse_gpl_contribs "contrib/$TRIPLET"

[ -f configure ] || ./bootstrap

# VideoLAN's own options (extras/package/win32/configure.sh and build.sh's -z), but for the GPL modules they enable:
# faad, live555, the Real RTSP access, the Musepack demuxer, libzvbi and libdvdread.
configure_flags="--host=$TRIPLET --with-contrib=../contrib/$TRIPLET --prefix=$prefix
  --disable-update-check --disable-nls --disable-vlc --disable-qt --disable-skins2 --disable-lua
  --enable-flac --enable-theora --enable-avcodec --enable-merge-ffmpeg --enable-libass --enable-schroedinger
  --enable-shout --enable-goom --enable-sse --enable-mmx --enable-libcddb --enable-caca
  --enable-bluray
  --disable-faad --disable-live555 --disable-realrtsp --disable-mpc --disable-dvdread --disable-dvdnav
  --disable-a52 --disable-dca --disable-libmpeg2 --disable-mad --disable-x264 --disable-x26410b --disable-x265
  --disable-x262 --disable-postproc --disable-vnc --disable-sid --disable-samplerate
  --disable-gnutls --disable-wma-fixed --disable-zvbi --enable-telx"
mkdir -p win64
cd win64
if [ ! -f config.status ] || [ "$(cat yonto-configure-flags 2> /dev/null)" != "$configure_flags" ]; then
  # shellcheck disable=SC2086
  CPPFLAGS="$cppflags" CFLAGS="$cppflags" CXXFLAGS="$cppflags" PKG_CONFIG=pkg-config \
    PKG_CONFIG_LIBDIR="/usr/$TRIPLET/lib/pkgconfig:/usr/lib/$TRIPLET/pkgconfig" ../configure $configure_flags
  echo "$configure_flags" > yonto-configure-flags
fi
make -j"$jobs"
rm -rf "$prefix" package-win-install vlc-*/sdk
make package-win-sdk

stage=/work/stage
rm -rf "$stage"
mkdir -p "$stage/plugins"
cp "$prefix/bin/libvlc.dll" "$prefix/bin/libvlccore.dll" "$prefix/lib/vlc/vlc-cache-gen.exe" "$stage/"
cp -r vlc-*/sdk "$stage/sdk"
cp ../COPYING.LIB "$stage/"
copy_lgpl_plugins "$prefix/lib/vlc/plugins" "$stage/plugins" dll
refuse_gpl_core
find "$stage" \( -name '*.dll' -o -name '*.exe' \) -exec "$TRIPLET-strip" --strip-unneeded {} +

# shellcheck disable=SC2046
refuse_gpl_binaries $(find "$stage" -name '*.dll')
check_ffmpeg "$stage/plugins/codec/libavcodec_plugin.dll"
for plugin in access/liblibbluray codec/libd3d11va codec/liblibass demux/libmkv video_output/libdirect3d11 \
    video_filter/libdeinterlace; do
  [ -f "$stage/plugins/${plugin}_plugin.dll" ] || { echo "the plugins have no $plugin" >&2; exit 1; }
done

zip="/out/libvlc-windows-x64-$VERSION.zip"
rm -f "$zip"
(cd "$stage" && zip -q -r -9 "$zip" .)
sha256sum "$zip"

#!/bin/sh
# Builds the libVLC the Linux app ships, for x64: the same VLC commit, patches and GPL exclusions as the Windows one
# (tools/libvlc-windows/build.sh says which and why; ../vlc/build-common.sh is what the two share), built in Debian 11, so it
# runs on any distribution with glibc 2.31 or later (docs/design/2026-11-25-yonto-on-linux.md).
# What belongs to the viewer's system is the system's own: X11 and xcb, OpenGL, fontconfig and FreeType, ALSA and
# PulseAudio, D-Bus, VA-API and VDPAU. The codecs, demuxers and libass are VLC's contribs, linked into the plugins.
# libva and libvdpau are the system's because they have to match its drivers, but FFmpeg is linked to them and would not
# load without them, and nor would the picture's window without xcb's smaller libraries, so a copy of each is in fallback/,
# which the app loads only where the system has none (`LibVlc.load`).
# Writes libvlc-linux-x64-$VERSION.tar.gz (libvlc.so.5, libvlccore.so.9, vlc/plugins/ with plugins.dat, fallback/ and
# COPYING.LIB) into the output folder; what yonto-app/libvlc-lgpl's releases keep is a copy.
#
#   tools/libvlc-linux/build.sh [outdir]      outdir defaults to build/libvlc-linux
#
# Needs Docker able to run linux/amd64 images (on an Apple Silicon Mac, a Colima profile with --vz-rosetta). The build
# tree lives in the Docker volume $LIBVLC_LINUX_VOLUME, so a second run resumes where the first stopped.
set -eu

VLC_HASH=c9dde25a62c4612d71250c4eb845154e0ea9e13e
VERSION=3.0.22-rc1-1
GLIBC=2.31
TRIPLET=x86_64-linux-gnu

here="$(cd "$(dirname "$0")" && pwd)"

if [ "${1:-}" != --inside ]; then
  root="$(cd "$here/../.." && pwd)"
  out="${1:-$root/build/libvlc-linux}"
  mkdir -p "$out"
  out="$(cd "$out" && pwd)"
  volume="${LIBVLC_LINUX_VOLUME:-yonto-libvlc-linux}"
  docker build --platform linux/amd64 -t yonto-libvlc-linux "$here"
  docker volume create "$volume" > /dev/null
  docker run --rm --platform linux/amd64 --user root -v "$volume:/work" yonto-libvlc-linux chown builder:builder /work
  exec docker run --rm --platform linux/amd64 -v "$volume:/work" -v "$here/..:/tools:ro" -v "$out:/out" \
    yonto-libvlc-linux sh /tools/libvlc-linux/build.sh --inside
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

mkdir -p contrib/contrib-linux
cd contrib/contrib-linux
# As Windows', and what only its desktop would use: goom, projectM and the like are visualisations nothing here shows,
# upnp, microdns, dsm, smb2, nfs and ssh2 are places the app reads itself, and protobuf is Chromecast's.
../bootstrap --prefix="../$TRIPLET" --disable-gpl --disable-gnuv3 --enable-ad-clauses \
  --disable-lua --disable-luac --disable-asdcplib --disable-zvbi --disable-qt --disable-qtsvg --disable-qtdeclarative \
  --disable-qtgraphicaleffects --disable-qtquickcontrols2 --disable-qtwayland \
  --disable-goom --disable-projectM --disable-caca --disable-upnp --disable-microdns --disable-dsm --disable-smb2 \
  --disable-nfs --disable-ssh2 --disable-protobuf --disable-sparkle --disable-breakpad --disable-growl \
  --disable-fluidlite --disable-spatialaudio --disable-chromaprint --disable-SDL_image --disable-sdl --disable-srt --disable-medialibrary
make_contribs
cd ../..

refuse_gpl_contribs "contrib/$TRIPLET"

[ -f configure ] || ./bootstrap

configure_flags="--with-contrib=$vlc/contrib/$TRIPLET --prefix=$prefix
  --disable-update-check --disable-nls --disable-vlc --disable-qt --disable-skins2 --disable-lua --disable-a52
  --disable-ncurses --disable-sdl-image --disable-notify --disable-kwallet --disable-secret --disable-avahi
  --disable-udev --disable-mtp --disable-v4l2 --disable-decklink --disable-gst-decode --disable-chromecast
  --disable-dc1394 --disable-dv1394 --disable-linsys --disable-wayland --disable-aa --disable-caca --disable-goom
  --disable-projectm --disable-vsxu --disable-jack --disable-oss --disable-upnp --disable-dsm --disable-smbclient
  --disable-nfs --disable-sftp --disable-srt --disable-chromaprint --disable-fluidsynth --disable-spatialaudio
  --enable-flac --enable-theora --enable-avcodec --enable-merge-ffmpeg --enable-libass --enable-schroedinger
  --enable-sse --enable-mmx --enable-bluray --enable-libva --enable-vdpau --enable-xcb --enable-pulse --enable-alsa
  --disable-faad --disable-live555 --disable-realrtsp --disable-mpc --disable-dvdread --disable-dvdnav
  --disable-dca --disable-libmpeg2 --disable-mad --disable-x264 --disable-x26410b --disable-x265
  --disable-x262 --disable-postproc --disable-vnc --disable-sid --disable-samplerate
  --disable-gnutls --disable-wma-fixed --disable-zvbi --enable-telx"
mkdir -p linux
cd linux
if [ ! -f config.status ] || [ "$(cat yonto-configure-flags 2> /dev/null)" != "$configure_flags" ]; then
  # shellcheck disable=SC2086
  ../configure $configure_flags
  echo "$configure_flags" > yonto-configure-flags
fi
make -j"$jobs"
rm -rf "$prefix"
make install

stage=/work/stage
rm -rf "$stage"
mkdir -p "$stage/vlc/plugins" "$stage/fallback"
cp -L "$prefix/lib/libvlc.so.5" "$prefix/lib/libvlccore.so.9" "$stage/"
# libvlc_pulse and the like, which a plugin shares with another.
find "$prefix/lib/vlc" -maxdepth 1 -name 'libvlc_*.so.0' -exec cp -L {} "$stage/vlc/" \;
cp ../COPYING.LIB "$stage/"
copy_lgpl_plugins "$prefix/lib/vlc/plugins" "$stage/vlc/plugins" so
refuse_gpl_core
for library in libva.so.2 libva-drm.so.2 libva-x11.so.2 libvdpau.so.1 libxcb-keysyms.so.1 libxcb-composite.so.0 \
    libxcb-randr.so.0 libxcb-shm.so.0 libxcb-xv.so.0 libXfixes.so.3; do
  cp -L "/usr/lib/$TRIPLET/$library" "$stage/fallback/"
done
find "$stage" -type f -name '*.so*' -exec strip --strip-unneeded {} +
# libVLC is found beside what loads it, never by the folder it was built in. libva-drm and libva-x11 need libva.
patchelf --set-rpath '$ORIGIN' "$stage/libvlc.so.5" "$stage/libvlccore.so.9" "$stage"/vlc/libvlc_*.so.0 "$stage"/fallback/*
for plugin in "$stage"/vlc/plugins/*/*.so; do
  patchelf --set-rpath '$ORIGIN/../..:$ORIGIN/../../..' "$plugin"
done

# shellcheck disable=SC2046
refuse_gpl_binaries $(find "$stage" -name '*.so*')
check_ffmpeg "$stage/vlc/plugins/codec/libavcodec_plugin.so"
for plugin in access/liblibbluray codec/libvaapi_drm codec/liblibass demux/libmkv video_output/libgl video_output/libglx \
    video_output/libxcb_x11 video_output/libxcb_window video_filter/libdeinterlace audio_output/libpulse audio_output/libalsa; do
  ls "$stage/vlc/plugins/${plugin}"*_plugin.so > /dev/null 2>&1 || { echo "the plugins have no $plugin" >&2; exit 1; }
done

# Nothing may ask for a newer glibc than the one this is built for, nor for a library that is neither here nor the system's.
newest="$(find "$stage" -type f -name '*.so*' -exec objdump -T {} + | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -n 1)"
[ "$(printf 'GLIBC_%s\n%s\n' "$GLIBC" "$newest" | sort -V | tail -n 1)" = "GLIBC_$GLIBC" ] || { echo "$newest is newer than glibc $GLIBC" >&2; exit 1; }
system='^lib(c|m|dl|rt|pthread|gcc_s|stdc\+\+|z|X11|Xext|Xfixes|png16|xcb|xcb-(composite|keysyms|randr|shm|xv)|GL|EGL|drm|fontconfig|freetype|dbus-1|asound|pulse|va|va-drm|va-x11|vdpau|vlc|vlccore|vlc_(pulse|vdpau|xcb_events))\.so\.[0-9]+$|^ld-linux-x86-64\.so\.2$'
strange="$(find "$stage" -type f -name '*.so*' -exec objdump -p {} + | awk '$1 == "NEEDED" { print $2 }' | sort -u | grep -v -E "$system" || true)"
if [ -n "$strange" ]; then
  echo "the plugins need libraries a system may not have:" >&2
  echo "$strange" >&2
  exit 1
fi

# The plugins' cache, as an installed copy would write it: without it libVLC opens every plugin on each start.
LD_LIBRARY_PATH="$stage" "$prefix/lib/vlc/vlc-cache-gen" "$stage/vlc/plugins"
[ -f "$stage/vlc/plugins/plugins.dat" ] || { echo "no plugins.dat was written" >&2; exit 1; }

archive="/out/libvlc-linux-x64-$VERSION.tar.gz"
rm -f "$archive"
tar -C "$stage" --sort=name --owner=0 --group=0 -czf "$archive" .
sha256sum "$archive"

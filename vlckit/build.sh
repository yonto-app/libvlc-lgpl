#!/bin/sh
# Builds the VLCKit the iOS, Apple TV and Mac apps ship: VideoLAN's own VLCKit and libVLC sources at the version
# tools/fetch-vlckit.sh pins, configured as VideoLAN configures them but with libbluray on, which their prebuilt
# frameworks leave out, so a Blu-ray ISO plays (docs/design/2026-10-04-files-and-network-libraries.md).
# buildMobileVLCKit.patch turns libbluray on and sets the apps' own deployment targets, which current Xcode needs (the
# Apple TV's is TVVLCKit, VLCKit 3's own framework for tvOS);
# vlc/ holds the patches VLCKit's script applies to VLC beside its own: libbluray building for iOS and tvOS, subtitles
# blended over a hardware decoder's picture once it is converted, blend taking P010, libass's `ssa-font`, the font
# the apps ship, and FFmpeg's TrueHD and MLP decoders, which VLCKit's own patches turn off; ../vlc/ holds the ones both
# libVLC builds apply (FFmpeg's AVS+ decoder, a decoder made while paused told of the pause, a subtitle file given an
# ES id no other track holds, deinterlace without Yadif, which is GPL, and `libvlc_video_set_sub_margin`, which lifts the
# subtitles of a player already playing, so the apps keep them above their controls).
# Nothing GPL is in it: buildMobileVLCKit.patch turns Real RTSP and libzvbi off (teletext falls back to VLC's own telx)
# and deletes every plugin made from a GPL source (../vlc/gpl.sh) before they are linked.
# Writes one tar.xz per platform; what yonto-app/libvlc-lgpl's releases keep (which fetch-vlckit.sh pins) are copies.
#
#   tools/vlckit/build.sh [outdir]      outdir defaults to build/vlckit, and the sources go in build/vlckit-src,
#                                       both under the folder it is run from
#
# Needs macOS with Xcode and Homebrew's autoconf automake libtool pkg-config cmake meson ninja nasm gettext ragel.
set -eu

VLCKIT_TAG=3.7.3
VERSION=3.7.3-6

here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${1:-build/vlckit}" "${VLCKIT_WORK:-build/vlckit-src}"
out="$(cd "${1:-build/vlckit}" && pwd)"
work="$(cd "${VLCKIT_WORK:-build/vlckit-src}" && pwd)"
cd "$work"

[ -d VLCKit ] || git clone --depth 1 --branch "$VLCKIT_TAG" https://code.videolan.org/videolan/VLCKit.git
cd VLCKit
git checkout -q -- buildMobileVLCKit.sh
git apply "$here/buildMobileVLCKit.patch"
cp "$here"/vlc/*.patch "$here"/../vlc/*.patch libvlc/patches/

# Homebrew's autoconf adds -std=gnu23, which the K&R C in some contribs does not compile under.
export ac_cv_prog_cc_c23=no
export GPL_SH="$here/../vlc/gpl.sh"
./buildMobileVLCKit.sh -f
./buildMobileVLCKit.sh -t -f
./buildMobileVLCKit.sh -x

. "$GPL_SH"
core="$(gpl_core_sources "$work/VLCKit/libvlc/vlc")"
if [ -n "$core" ]; then
  echo "libvlccore or libvlc is built from GPL sources: $core" >&2
  exit 1
fi

check() {
  binary="$1"
  strings -a "$binary" | grep -q 'BluRay demuxer' || { echo "$binary has no libbluray" >&2; exit 1; }
  strings -a "$binary" | grep -q 'Enhanced field coded P picture' || { echo "$binary has no AVS+ decoder" >&2; exit 1; }
  strings -a "$binary" | grep -q 'MLP only supports up to 2 substreams' || { echo "$binary has no TrueHD decoder" >&2; exit 1; }
  if strings -a "$binary" | grep -q -E 'x264 advanced options|DVDOpen' ||
      nm -a "$binary" | grep -q -E 'RenderYadif|vbi_decoder_new|vlc_entry__(audio_filter_channel_mixer_(dolby|mono)|control_dummy|misc_rtsp|video_filter_rotate)$'; then
    echo "$binary holds GPL code" >&2
    exit 1
  fi
}
check build/MobileVLCKit.xcframework/ios-arm64/MobileVLCKit.framework/MobileVLCKit
check build/TVVLCKit.xcframework/tvos-arm64/TVVLCKit.framework/TVVLCKit
check build/VLCKit.xcframework/macos-arm64_x86_64/VLCKit.framework/Versions/A/VLCKit

tar -cJf "$out/MobileVLCKit-$VERSION.tar.xz" -C build MobileVLCKit.xcframework
tar -cJf "$out/TVVLCKit-$VERSION.tar.xz" -C build TVVLCKit.xcframework
tar -cJf "$out/VLCKit-$VERSION.tar.xz" -C build VLCKit.xcframework
shasum -a 256 "$out"/*-"$VERSION".tar.xz

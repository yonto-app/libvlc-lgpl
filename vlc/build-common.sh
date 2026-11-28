# What the desktop libVLC builds (tools/libvlc-windows, tools/libvlc-linux) share, sourced inside their containers with
# $vlc (VLC's tree), $patches (what it holds, one to a line) and $jobs set: VLC's sources at a commit with the patches,
# its contribs fetched, and the scan that keeps every module built from a GPL source out of what ships (gpl.sh, which
# VLCKit's build sources too).

. /tools/vlc/gpl.sh

# Each patch must be in VLC as it is here, not only by its Message-Id: a volume cloned before a patch was added or
# changed never applies it again.
check_patches() {
  for patch in $patches; do
    id="$(sed -n 's/^Message-Id: <\(.*\)>$/\1/p' "$patch" | head -n 1)"
    commit="$(git -C "$vlc" log --format=%H --fixed-strings --grep="$id" | head -n 1)"
    if [ -z "$commit" ] || [ "$(git -C "$vlc" -c diff.suppressBlankEmpty=false diff-tree -p "$commit" | git patch-id --stable | cut -d' ' -f1)" != \
        "$(git patch-id --stable < "$patch" | cut -d' ' -f1)" ]; then
      echo "VLC in the volume does not hold $(basename "$patch") as it is now: remove the volume and build again" >&2
      exit 1
    fi
  done
}

# VLC 3.0.x at commit $1, with the patches.
clone_vlc() {
  if [ ! -d "$vlc" ]; then
    rm -rf "$vlc.partial"
    git clone --single-branch --branch 3.0.x https://code.videolan.org/videolan/vlc.git "$vlc.partial"
    git -C "$vlc.partial" reset --hard "$1"
    # shellcheck disable=SC2086
    git -C "$vlc.partial" -c user.name=yonto-app -c user.email=336298264+yonto-app@users.noreply.github.com \
      am --message-id $patches
    mv "$vlc.partial" "$vlc"
  fi
  check_patches
}

# The contribs the current folder is bootstrapped for, fetched and built.
make_contribs() {
  make list
  # A download cut short by an earlier run is fetched again.
  for tarball in ../tarballs/*.tar.* ../tarballs/*.tgz ../tarballs/*.zip; do
    [ -f "$tarball" ] || continue
    sums="$(grep -h " $(basename "$tarball")\$" ../src/*/SHA512SUMS || true)"
    if [ -n "$sums" ] && ! (cd ../tarballs && echo "$sums" | sha512sum --check --status); then
      rm "$tarball"
    fi
  done
  # The contribs' SourceForge mirror no longer resolves, and a stalled mirror would hang the build rather than fail it.
  sf=SF=https://downloads.sourceforge.net/project
  mkdir -p /work/curl
  printf 'speed-limit = 4096\nspeed-time = 60\nconnect-timeout = 30\n' > /work/curl/.curlrc
  export CURL_HOME=/work/curl
  make -j"$jobs" "$sf" fetch
  # CMake sometimes never hears of its child under Rosetta, so a step killed for it is tried again.
  make -j"$jobs" "$sf" -k || make -j"$jobs" "$sf" -k || make -j1 "$sf"
}

# Stops where the contribs in folder $1 hold a library that is GPL or LGPLv3.
refuse_gpl_contribs() {
  for gpl in a52 dca dvdread dvdnav dvdcss faad libmpeg2 mad x264 x265 x262 sidplay2 samplerate vncclient postproc gnutls nettle zvbi; do
    if ls "$1/lib/lib$gpl"* > /dev/null 2>&1; then
      echo "the contribs hold $gpl, which is GPL or LGPLv3" >&2
      exit 1
    fi
  done
}

# Copies every plugin of folder $1 that no GPL source is in to folder $2, naming the ones left out; .$3 is their extension.
copy_lgpl_plugins() {
  left_out=""
  for plugin in "$1"/*/*."$3"; do
    name="$(basename "$plugin" ".$3")"
    gpl="$(gpl_sources_of "$vlc" "$PWD" "$name" | tr '\n' ' ')"
    if [ -n "$gpl" ]; then
      left_out="$left_out
  $name: $gpl"
      continue
    fi
    mkdir -p "$2/$(basename "$(dirname "$plugin")")"
    cp "$plugin" "$2/$(basename "$(dirname "$plugin")")/"
  done
  echo "Left out, as built from GPL sources:$left_out"
}

# Stops where libvlc or libvlccore is made from a GPL source.
refuse_gpl_core() {
  core="$(gpl_core_sources "$vlc")"
  if [ -n "$core" ]; then
    echo "libvlccore or libvlc is built from GPL sources: $core" >&2
    exit 1
  fi
}

# Stops where any of the binaries given holds GPL code, by what that code says of itself.
refuse_gpl_binaries() {
  if strings -a "$@" | grep -q -E 'x264 advanced options|live555\.cpp|DVDOpen|--enable-gpl'; then
    echo "the libraries still hold GPL code" >&2
    exit 1
  fi
}

# Stops where the FFmpeg plugin $1 is not LGPL 2.1 or cannot decode AVS+.
check_ffmpeg() {
  strings -a "$1" | grep -q 'Enhanced field coded P picture' || { echo "$(basename "$1") has no AVS+ decoder" >&2; exit 1; }
  strings -a "$1" | grep -q 'LGPL version 2.1 or later' || { echo "FFmpeg is not LGPL-2.1" >&2; exit 1; }
}

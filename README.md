# libVLC, LGPL-only, for Yonto Player on Android

VideoLAN's `libvlc-all` on Maven Central is labelled LGPL but its `libvlc.so` holds GPL code (the x264 encoder and libdvdread).
This is libVLC 3.6.5 built from VideoLAN's own, unmodified sources with VideoLAN's LGPL contrib option (`--license a`, which passes `--disable-gpl`), so no GPL library is in it and FFmpeg is configured without `--enable-gpl`.
It has no video encoder.

| | |
| --- | --- |
| Artifact | `app.yonto.vendor:libvlc-lgpl:3.6.5-1` (AAR; arm64-v8a and armeabi-v7a) |
| SHA-256 | `2838c630cc82ed716c9d8093a3148fb6fbe1e06cba0b56e4b7d10d51e151f963` |
| Licence | LGPL-2.1-or-later (`COPYING.LGPL-2.1`) |
| Source | https://code.videolan.org/videolan/vlc-android (tag `libvlc-3.6.5`), https://code.videolan.org/videolan/libvlcjni (branch `libvlcjni-3.x`, commit `965e8648717076654f463ae64ee1d008d7ff282d`), and the VLC commit `c9dde25a62c4612d71250c4eb845154e0ea9e13e` that commit fetches |
| Recipe | `build.sh`, which needs the Android SDK, NDK 28 and NDK 21, JDK 17 and the tools its header lists; it is the exact script that makes the AAR |

Yonto Player carries the libraries as the shared `libvlc.so` and `libvlcjni.so`, not linked into its own code.
Anyone may replace them with a build of their own from the recipe above.

Use it from Gradle as a Maven repository pinned to a commit of this repository:

```kotlin
maven("https://raw.githubusercontent.com/yonto-app/libvlc-lgpl/<commit>/maven")
```

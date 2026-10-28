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
maven("https://raw.githubusercontent.com/kangzj/libvlc-lgpl/<commit>/maven")
```

# VLCKit with libbluray, for Yonto Player on iOS, the Apple TV and the Mac

VideoLAN's prebuilt VLCKit leaves libbluray out (`--disable-bluray`), so it cannot open a Blu-ray disc image.
This is VLCKit 3.7.3 built from VideoLAN's own sources as VideoLAN configures it, with four changes, all in `vlckit/`:

- libbluray is turned on (`buildMobileVLCKit.patch`), and the Mac framework links DiskArbitration, which libbluray uses there.
- The deployment targets are iOS 16.0, tvOS 18.0 and macOS 13.0, since current Xcode refuses VLCKit's iOS 9.0 and tvOS 10.2.
- libbluray's build is patched to build for iOS, which has no DiskArbitration (`vlc/0100-…patch`, which adds `contrib/src/bluray/0002-Build-for-iOS-which-has-no-DiskArbitration.patch` to VLC), and for tvOS, which cannot start a process (`vlc/0101-…patch`, which adds `contrib/src/bluray/0003-Build-for-tvOS-which-cannot-start-a-process.patch`).
- Since 3.7.3-2, subtitles are drawn on iOS and tvOS, where VideoToolbox's pictures have no planes to blend them into and the system has no CJK font an app can open: the video output blends an opaque picture's subtitles once it is converted (`vlc/0102-…patch`), the blend module takes P010 (`vlc/0103-…patch`), and libass takes `--ssa-font`, a font file used instead of the system's (`vlc/0104-…patch`).

Like VideoLAN's, it is built with `--disable-gpl`, and `build.sh` fails when the result holds no libbluray or a GPL string.

| | |
| --- | --- |
| Artifacts | `MobileVLCKit-3.7.3-2.tar.xz` (iOS: arm64, and arm64 and x86_64 for the simulator), `TVVLCKit-3.7.3-2.tar.xz` (tvOS: arm64, and arm64 and x86_64 for the simulator) and `VLCKit-3.7.3-2.tar.xz` (the Mac: arm64 and x86_64), on this repository's release `vlckit-3.7.3-2` |
| SHA-256 | `27ff8965a4366840ed9f02f1f2d8532c45b9b8060e8e4ad35afc7a5ddcf019fb` (MobileVLCKit), `6c3f089a1f4198197b6d86e8b0594dd8fdd9a97ed4fbdb6c6ac309cd076cd928` (TVVLCKit), `047601691bd9cd276091f0bbe2849c1e5bc429e9b3142de4996e1d2af007507d` (VLCKit) |
| Licence | LGPL-2.1-or-later (`COPYING.LGPL-2.1`) |
| Source | https://code.videolan.org/videolan/VLCKit (tag `3.7.3`), and the VLC commit and patches that tag's `buildMobileVLCKit.sh` fetches and applies |
| Recipe | `vlckit/build.sh`, which needs macOS with Xcode and the tools its header lists; it is the exact script that makes the archives |

Yonto Player embeds the framework as a dynamic framework, not linked into its own code, so anyone may replace it with a build of their own from the recipe above.

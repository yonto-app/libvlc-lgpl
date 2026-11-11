# libVLC, LGPL-only, for Yonto Player on Android

VideoLAN's `libvlc-all` on Maven Central is labelled LGPL but its `libvlc.so` holds GPL code (the x264 encoder and libdvdread).
This is libVLC 3.6.5 built from VideoLAN's own sources with VideoLAN's LGPL contrib option (`--license a`, which passes `--disable-gpl`), so no GPL library is in it and FFmpeg is configured without `--enable-gpl`.
It has no video encoder.
Since 3.6.5-2 it has one change, which the VLCKit below has too: FFmpeg's own decoder for AVS+ (AVS1-P16, the Broadcasting profile), which FFmpeg's master branch gained on 2026-11-02, backported onto the FFmpeg 4.4.5 that VLC's contribs build (`vlc/0200-…patch`, which adds `contrib/src/ffmpeg/avsplus.patch` to VLC).
Since 3.6.5-3 it has a second: a decoder made while the input is paused is told of the pause, so a paused title that is left and come back to draws its picture (`vlc/0201-…patch`, adapted from VLC master's `44a4e0b0b30dd1080ac1003ba50aa4d98ab88c6d`).
The VLCKit 3.7.3-3 archives below were built before that patch, so they do not have it, though `vlckit/build.sh` applies `vlc/`'s patches too.
`libvlc/build.sh` fails when the result holds a GPL string or no AVS+ decoder, or when a patch in `vlc/` was not applied.

| | |
| --- | --- |
| Artifact | `app.yonto.vendor:libvlc-lgpl:3.6.5-3` (AAR; arm64-v8a and armeabi-v7a); 3.6.5-2, without the second change, and 3.6.5-1, without either, stay beside it |
| SHA-256 | `22f7a770dba9d7fd57bebead7db898e0ff3e1acbe360f580c48710a1582c0aaa` |
| Licence | LGPL-2.1-or-later (`COPYING.LGPL-2.1`) |
| Source | https://code.videolan.org/videolan/vlc-android (tag `libvlc-3.6.5`), https://code.videolan.org/videolan/libvlcjni (branch `libvlcjni-3.x`, commit `965e8648717076654f463ae64ee1d008d7ff282d`), and the VLC commit `c9dde25a62c4612d71250c4eb845154e0ea9e13e` that commit fetches, with `vlc/`'s patches |
| Recipe | `libvlc/build.sh`, which needs the Android SDK, NDK 28 and NDK 21, JDK 17 and the tools its header lists; it is the exact script that makes the AAR |

Yonto Player carries the libraries as the shared `libvlc.so` and `libvlcjni.so`, not linked into its own code.
Anyone may replace them with a build of their own from the recipe above.

Use it from Gradle as a Maven repository pinned to a commit of this repository:

```kotlin
maven("https://raw.githubusercontent.com/kangzj/libvlc-lgpl/<commit>/maven")
```

# VLCKit with libbluray, for Yonto Player on iOS, the Apple TV and the Mac

VideoLAN's prebuilt VLCKit leaves libbluray out (`--disable-bluray`), so it cannot open a Blu-ray disc image.
This is VLCKit 3.7.3 built from VideoLAN's own sources as VideoLAN configures it, with five changes, in `vlckit/` and `vlc/`:

- libbluray is turned on (`buildMobileVLCKit.patch`), and the Mac framework links DiskArbitration, which libbluray uses there.
- The deployment targets are iOS 16.0, tvOS 18.0 and macOS 13.0, since current Xcode refuses VLCKit's iOS 9.0 and tvOS 10.2.
- libbluray's build is patched to build for iOS, which has no DiskArbitration (`vlc/0100-…patch`, which adds `contrib/src/bluray/0002-Build-for-iOS-which-has-no-DiskArbitration.patch` to VLC), and for tvOS, which cannot start a process (`vlc/0101-…patch`, which adds `contrib/src/bluray/0003-Build-for-tvOS-which-cannot-start-a-process.patch`).
- Since 3.7.3-2, subtitles are drawn on iOS and tvOS, where VideoToolbox's pictures have no planes to blend them into and the system has no CJK font an app can open: the video output blends an opaque picture's subtitles once it is converted (`vlc/0102-…patch`), the blend module takes P010 (`vlc/0103-…patch`), and libass takes `--ssa-font`, a font file used instead of the system's (`vlc/0104-…patch`).
- Since 3.7.3-3, AVS+ decodes, with the same FFmpeg change as the libVLC above (`../vlc/0200-…patch`).

Like VideoLAN's, it is built with `--disable-gpl`, and `build.sh` fails when the result holds no libbluray, no AVS+ decoder or a GPL string.

| | |
| --- | --- |
| Artifacts | `MobileVLCKit-3.7.3-3.tar.xz` (iOS: arm64, and arm64 and x86_64 for the simulator), `TVVLCKit-3.7.3-3.tar.xz` (tvOS: arm64, and arm64 and x86_64 for the simulator) and `VLCKit-3.7.3-3.tar.xz` (the Mac: arm64 and x86_64), on this repository's release `vlckit-3.7.3-3` |
| SHA-256 | `7057adaa5d647668a025e37d921390b1ac23879d43b860458372c2c362518955` (MobileVLCKit), `8fb55967ab3e69723752728fae68860f254419f49203d1c9d2d81915dcc79d24` (TVVLCKit), `a0ec33ef13a10b52ad818cae588180ae4fedaea964e70e621768150ba1ddf761` (VLCKit) |
| Licence | LGPL-2.1-or-later (`COPYING.LGPL-2.1`) |
| Source | https://code.videolan.org/videolan/VLCKit (tag `3.7.3`), and the VLC commit and patches that tag's `buildMobileVLCKit.sh` fetches and applies, with `vlckit/vlc/`'s and `vlc/`'s |
| Recipe | `vlckit/build.sh`, which needs macOS with Xcode and the tools its header lists; it is the exact script that makes the archives |

Yonto Player embeds the framework as a dynamic framework, not linked into its own code, so anyone may replace it with a build of their own from the recipe above.

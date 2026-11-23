# libVLC, LGPL-only, for Yonto Player on Android

VideoLAN's `libvlc-all` on Maven Central is labelled LGPL but its `libvlc.so` holds GPL code (the x264 encoder and libdvdread).
This is libVLC 3.6.5 built from VideoLAN's own sources with VideoLAN's LGPL contrib option (`--license a`, which passes `--disable-gpl`), so no GPL library is in it and FFmpeg is configured without `--enable-gpl`.
It has no video encoder.
Since 3.6.5-2 it has one change, which the VLCKit below has too: FFmpeg's own decoder for AVS+ (AVS1-P16, the Broadcasting profile), which FFmpeg's master branch gained on 2026-11-02, backported onto the FFmpeg 4.4.5 that VLC's contribs build (`vlc/0200-…patch`, which adds `contrib/src/ffmpeg/avsplus.patch` to VLC).
Since 3.6.5-3 it has a second: a decoder made while the input is paused is told of the pause, so a paused title that is left and come back to draws its picture (`vlc/0201-…patch`, adapted from VLC master's `44a4e0b0b30dd1080ac1003ba50aa4d98ab88c6d`).
The VLCKit archives below have it since 3.7.3-4.
Since 3.6.5-4 it has a third, Android's alone (`libvlc/vlc/0300-…patch`, which VLCKit does not take, having no AudioTrack): VideoLAN's own `f1369aeb95f89d1afb8ebec4403c30b45ff3e863` from VLC 3.0.x, which keeps a DynamicsProcessing effect Android refuses from marking the AudioTrack failed. Without it a 5.1 track played on a DIRECT output, where Android refuses the effect, is never written and plays silent.
`libvlc/build.sh` fails when the result holds a GPL string, no AVS+ decoder or no AudioTrack fix, or when a patch in `vlc/` or `libvlc/vlc/` was not applied.

| | |
| --- | --- |
| Artifact | `app.yonto.vendor:libvlc-lgpl:3.6.5-4` (AAR; arm64-v8a and armeabi-v7a); 3.6.5-3, without the third change, 3.6.5-2, without the second, and 3.6.5-1, without any, stay beside it |
| SHA-256 | `e998cf2265a7f0f82556baceaa8130a73a13fcb2433097f6effc2ea2506b6572` |
| Licence | LGPL-2.1-or-later (`COPYING.LGPL-2.1`) |
| Source | https://code.videolan.org/videolan/vlc-android (tag `libvlc-3.6.5`), https://code.videolan.org/videolan/libvlcjni (branch `libvlcjni-3.x`, commit `965e8648717076654f463ae64ee1d008d7ff282d`), and the VLC commit `c9dde25a62c4612d71250c4eb845154e0ea9e13e` that commit fetches, with `vlc/`'s and `libvlc/vlc/`'s patches |
| Recipe | `libvlc/build.sh`, which needs the Android SDK, NDK 28 and NDK 21, JDK 17 and the tools its header lists; it is the exact script that makes the AAR |

Yonto Player carries the libraries as the shared `libvlc.so` and `libvlcjni.so`, not linked into its own code.
Anyone may replace them with a build of their own from the recipe above.

Use it from Gradle as a Maven repository pinned to a commit of this repository:

```kotlin
maven("https://raw.githubusercontent.com/yonto-app/libvlc-lgpl/<commit>/maven")
```

# VLCKit with libbluray, for Yonto Player on iOS, the Apple TV and the Mac

VideoLAN's prebuilt VLCKit leaves libbluray out (`--disable-bluray`), so it cannot open a Blu-ray disc image.
This is VLCKit 3.7.3 built from VideoLAN's own sources as VideoLAN configures it, with six changes, in `vlckit/` and `vlc/`:

- libbluray is turned on (`buildMobileVLCKit.patch`), and the Mac framework links DiskArbitration, which libbluray uses there.
- The deployment targets are iOS 16.0, tvOS 18.0 and macOS 13.0, since current Xcode refuses VLCKit's iOS 9.0 and tvOS 10.2.
- libbluray's build is patched to build for iOS, which has no DiskArbitration (`vlc/0100-…patch`, which adds `contrib/src/bluray/0002-Build-for-iOS-which-has-no-DiskArbitration.patch` to VLC), and for tvOS, which cannot start a process (`vlc/0101-…patch`, which adds `contrib/src/bluray/0003-Build-for-tvOS-which-cannot-start-a-process.patch`).
- Since 3.7.3-2, subtitles are drawn on iOS and tvOS, where VideoToolbox's pictures have no planes to blend them into and the system has no CJK font an app can open: the video output blends an opaque picture's subtitles once it is converted (`vlc/0102-…patch`), the blend module takes P010 (`vlc/0103-…patch`), and libass takes `--ssa-font`, a font file used instead of the system's (`vlc/0104-…patch`).
- Since 3.7.3-3, AVS+ decodes, with the same FFmpeg change as the libVLC above (`../vlc/0200-…patch`).
- Since 3.7.3-4, Dolby TrueHD and MLP decode: VLCKit's own `0003-Enable-System-DL.patch` turns FFmpeg's mlp decoder, demuxer and parser off, and the TrueHD decoder needs the mlp parser, so a TrueHD track played silent; `vlckit/vlc/0105-…patch` keeps FFmpeg's defaults. 3.7.3-4 also has `../vlc/0201-…patch` (a decoder made while paused is told of the pause), which 3.7.3-3 was built without.

Like VideoLAN's, it is built with `--disable-gpl`, and `build.sh` fails when the result holds no libbluray, no AVS+ decoder, no TrueHD decoder or a GPL string.

| | |
| --- | --- |
| Artifacts | `MobileVLCKit-3.7.3-4.tar.xz` (iOS: arm64, and arm64 and x86_64 for the simulator), `TVVLCKit-3.7.3-4.tar.xz` (tvOS: arm64, and arm64 and x86_64 for the simulator) and `VLCKit-3.7.3-4.tar.xz` (the Mac: arm64 and x86_64), on this repository's release `vlckit-3.7.3-4` (earlier versions stay on their own releases) |
| SHA-256 | `e4b8a6a954687d16c5eec5fd55bbdc10eb11dd1d608e3f1dc827b2570ec978d2` (MobileVLCKit), `b0a4da146e978b61eb10b8c3c729c9771c014d6e686574a20074d7af8f5853fe` (TVVLCKit), `4d1862e0f1e97ffcfa2ae212c8afa6ffe69605f671dfbd6702f21f3c8a3253dc` (VLCKit) |
| Licence | LGPL-2.1-or-later (`COPYING.LGPL-2.1`) |
| Source | https://code.videolan.org/videolan/VLCKit (tag `3.7.3`), and the VLC commit and patches that tag's `buildMobileVLCKit.sh` fetches and applies, with `vlckit/vlc/`'s and `vlc/`'s |
| Recipe | `vlckit/build.sh`, which needs macOS with Xcode and the tools its header lists; it is the exact script that makes the archives |

Yonto Player embeds the framework as a dynamic framework, not linked into its own code, so anyone may replace it with a build of their own from the recipe above.

# libVLC, LGPL-only, for Yonto Player on Windows

This is libVLC 3.0.22-rc1 for Windows x64, built from VideoLAN's own VLC sources with mingw-w64 in the Docker image VideoLAN's CI builds Windows 3.0 in, as its `extras/package/win32/build.sh` builds it.
The contribs are built with `--disable-gpl --disable-gnuv3`, so no GPL or LGPLv3 library is in it (no x264, x265, a52, dca, faad2, mad, libmpeg2, libdvdread, libdvdnav, libdvdcss, live555, GnuTLS or libzvbi) and FFmpeg is configured without `--enable-gpl`; libbluray is kept, so a Blu-ray disc image plays.
Unlike Android's single `libvlc.so`, each VLC module is its own DLL, and some of VLC 3's own modules are GPL (Lua, the Real RTSP access and demuxer, the playlist exporters, the file logger, DirectShow and BDA capture), so every plugin built from a GPL source file is left out, by a scan of the sources each one is made from.
It has the two changes in `vlc/` that the Android build has (FFmpeg's AVS+ decoder, and a decoder made while paused told of the pause), and two of its own: `libvlc-windows/vlc/0400-…patch` builds the deinterlace plugin without Yadif, whose code is FFmpeg's GPL filter, falling back to its automatic mode when Yadif is asked for, and `libvlc-windows/vlc/0401-…patch` has libVLC trust its plugins cache by a plugin's size alone, since a Windows app package (MSIX) installs every file with the time it was installed, which would otherwise leave every plugin opened on each start.
`libvlc-windows/build.sh` fails when a GPL or LGPLv3 contrib is in the result, or when a patch was not applied.

| | |
| --- | --- |
| Artifact | `libvlc-windows-x64-3.0.22-rc1-2.zip` (`libvlc.dll`, `libvlccore.dll`, `plugins/`, `sdk/` with the headers and import libraries, and `vlc-cache-gen.exe`), on this repository's release `libvlc-windows-3.0.22-rc1-2` |
| SHA-256 | `f02bfed1c050f070d50e0c613d1e8b6c4f3fa4245c5655bb76533534fd33ee6a` |
| Licence | LGPL-2.1-or-later (`COPYING.LGPL-2.1`) |
| Source | https://code.videolan.org/videolan/vlc (branch `3.0.x`, commit `c9dde25a62c4612d71250c4eb845154e0ea9e13e`), with `vlc/`'s and `libvlc-windows/vlc/`'s patches |
| Recipe | `libvlc-windows/build.sh`, which needs Docker able to run linux/amd64 images; it is the exact script that makes the zip |

Yonto Player carries the libraries as the DLLs `libvlc.dll` and `libvlccore.dll` and the plugins beside them, not linked into its own code.
Anyone may replace them with a build of their own from the recipe above.

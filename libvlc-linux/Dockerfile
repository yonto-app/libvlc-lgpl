# What tools/libvlc-linux/build.sh builds in: Debian 11, whose glibc is 2.31, with the system libraries libVLC is linked to.
# Debian 11 has left Debian's mirrors, so its packages are a dated snapshot's, whose signatures have expired since.
FROM debian:bullseye
RUN printf 'deb [check-valid-until=no] http://snapshot.debian.org/archive/%s %s main\n' \
    debian/20260801T000000Z bullseye debian-security/20260801T000000Z bullseye-security > /etc/apt/sources.list \
  && rm -rf /etc/apt/sources.list.d/* \
  && apt-get -o Acquire::Retries=5 update && apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
    autoconf automake autopoint bison ca-certificates cmake curl file flex g++ gettext git gperf help2man libtool make \
    nasm patch patchelf pkg-config python3 python3-setuptools ragel texinfo unzip wget xz-utils yasm bzip2 \
    libasound2-dev libdbus-1-dev libdrm-dev libegl1-mesa-dev libfontconfig1-dev libfreetype6-dev libgl1-mesa-dev \
    libpulse-dev libva-dev libvdpau-dev libx11-dev libxext-dev \
    libxcb1-dev libxcb-composite0-dev libxcb-keysyms1-dev libxcb-randr0-dev libxcb-shm0-dev libxcb-xv0-dev \
  && rm -rf /var/lib/apt/lists/* && useradd --create-home builder
USER builder

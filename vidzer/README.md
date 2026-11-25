# Building locally

The GitHub Actions cache is evicted after 7 days without use, and Vidzer only
changes its libmpv every month or two, so the CI usually starts cold: two hours
for the LLVM toolchain on a 4-core runner, then every package. Releases are
built locally instead, on an Arch Linux that keeps the build directory (WSL2 is
fine; keep the checkout on the Linux file system, not under `/mnt`).

## Environment

The package set of the CI image (`ghcr.io/shinchiro/archlinux`, made by
shinchiro/archlinux-docker's `build_docker.yml`):

```sh
printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
pacman -Syu --needed base base-devel jq openssh git mercurial subversion ninja cmake ragel yasm nasm \
  asciidoc enca gperf unzip p7zip gcc-multilib llvm clang lld libc++ libc++abi python-cairo python-pip \
  curl lib32-gcc-libs lib32-glib2 wget mimalloc ccache
pip3 install --break-system-packages setuptools rst2pdf mako jsonschema meson
```

## Build

```sh
vidzer/build-local.sh toolchain   # first time only
vidzer/build-local.sh mpv         # update the packages, build mpv
vidzer/build-local.sh package     # release_x86_64/: the 7z files, versions.txt, logs.7z
```

`package` runs `vidzer/check-lgpl.sh` (the same check as the CI step) and writes
`versions.txt` with the revision and origin of every source, for the release notes.

## Release

Only after the package passed Vidzer's checks: create the release `lgpl-YYYYMMDD`
with `gh release create`, uploading `mpv-dev-x86_64-*.7z`, `mpv-x86_64-*.7z`,
`ffmpeg-x86_64-*.7z`, `versions.txt` and `logs.7z`, and name the mpv commit in the notes.

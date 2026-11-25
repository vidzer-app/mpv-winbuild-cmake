#!/bin/bash
# Builds the LGPL libmpv on a local Arch Linux (WSL2 or a real machine) with the
# same options as .github/workflows/llvm_clang.yml and mpv_clang.yml, keeping the
# build directory between runs: the toolchain is built once, later runs only
# rebuild what changed. The environment is the package set of the CI image
# (shinchiro/archlinux-docker, build_docker.yml); see vidzer/README.md.
#
# Usage: vidzer/build-local.sh [toolchain|mpv|package|all]   (default: all)
#   toolchain  LLVM / Clang and the MinGW toolchain (first run only, no PGO:
#              PGO only speeds up the compiler, the output is the same)
#   mpv        update every package to its pinned or latest revision, build mpv
#   package    pack the 7z files into release/, check the license, list revisions
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD
bit=x86_64
build=build_$bit
release=release_$bit

configure() {
  # Re-run every time: BUILDDATE (the date in the package names) is set at configure time.
  cmake -DTARGET_ARCH=$bit-w64-mingw32 -DCOMPILER_TOOLCHAIN=clang \
    -DCMAKE_INSTALL_PREFIX="$root/clang_root" \
    -DMINGW_INSTALL_PREFIX="$root/$build/$bit-w64-mingw32" \
    -DSINGLE_SOURCE_LOCATION="$root/src_packages" \
    -DRUSTUP_LOCATION="$root/clang_root/install_rustup" \
    -DENABLE_CCACHE=ON -DCLANG_PACKAGES_LTO=ON \
    -G Ninja -B "$build" -S "$root"
}

toolchain() {
  configure
  ninja -C "$build" llvm
  ninja -C "$build" rustup
  ninja -C "$build" llvm-clang
}

mpv() {
  configure
  # mpv-packaging packs every mpv-* directory at the top of the build directory;
  # the CI deletes them after uploading, here they are left from the last run.
  find "$build" -maxdepth 1 -name 'mpv-*' -exec rm -rf {} +
  ninja -C "$build" download || true
  ninja -C "$build" update
  ninja -C "$build" mpv
}

package() {
  rm -rf "$release"
  mkdir -p "$release"
  ninja -C "$build" mpv-packaging
  mv "$build"/mpv*.7z "$release"/
  rm -f "$release"/mpv-debug-*.7z
  hash=$(git -C src_packages/ffmpeg rev-parse --short HEAD)
  7z a -m0=lzma2 -mx=9 -ms=on "$release/ffmpeg-$bit-git-$hash.7z" "./$build/$bit-w64-mingw32/bin/ffmpeg.exe"
  vidzer/check-lgpl.sh "$build"
  # Revisions of every source, for the release notes (LGPL: point to the sources).
  for dir in src_packages/*/; do
    name=$(basename "$dir")
    rev=$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo '-')
    url=$(git -C "$dir" remote get-url origin 2>/dev/null || echo '-')
    printf '%s %s %s\n' "$name" "$rev" "$url"
  done > "$release/versions.txt"
  mkdir -p "$release/logs"
  find "$build" -type f \( -iname '*-*.log' -o -wholename '*/ffbuild/config.log' \) -exec cp -f {} "$release/logs/" \; || true
  (cd "$release" && 7z a -m0=lzma2 -mx=9 -ms=on logs.7z logs >/dev/null && rm -rf logs)
  ls -la "$release"
}

case "${1:-all}" in
  toolchain) toolchain ;;
  mpv) mpv ;;
  package) package ;;
  all) toolchain; mpv; package ;;
  *) echo "usage: $0 [toolchain|mpv|package|all]" >&2; exit 2 ;;
esac

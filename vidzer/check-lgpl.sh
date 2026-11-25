#!/bin/bash
# Fails unless the FFmpeg and mpv of this build were configured without GPL parts.
# Reads the conclusions FFmpeg and mpv print at configure time; mpv.exe carries no
# FFmpeg configuration string, LTO strips avcodec_configuration() as unused.
# Usage: vidzer/check-lgpl.sh [build dir]   (default: build_x86_64)
set -euo pipefail
cd "$(dirname "$0")/.."
build=${1:-build_x86_64}
ffmpeg_log=$(find "$build/packages" -name ffmpeg-configure-out.log | head -1)
mpv_log=$(find "$build/packages" -name mpv-configure-out.log | head -1)
if [[ ! -f "$ffmpeg_log" || ! -f "$mpv_log" ]]; then
  echo 'error: configure logs of ffmpeg / mpv not found' >&2
  exit 1
fi
license=$(grep -m1 '^License:' "$ffmpeg_log" || true)
gpl=$(grep -m1 -E '^[[:space:]]+gpl[[:space:]]+:' "$mpv_log" || true)
echo "FFmpeg: $license"
echo "mpv:$gpl"
[[ "$license" == "License: LGPL version 3 or later" ]] || { echo "error: unexpected FFmpeg license: $license" >&2; exit 1; }
[[ "$gpl" =~ :[[:space:]]*false$ ]] || { echo 'error: mpv was not configured with -Dgpl=false' >&2; exit 1; }
echo 'LGPL check passed'

#!/bin/bash
# record-demo.sh: record the staged demo (Scrubby --demo) into assets/scrubby-demo.gif.
#
# The stage sits on top of everything in a 960×600 patch in the middle of the
# main display for about 15 s. It never touches the keyboard. Recording uses
# ScreenCaptureKit (macOS 15+) and needs Screen Recording permission for the
# terminal; the real cursor is left out (the stage draws its own). The raw take
# stays in build/demo/ for re-encoding.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
mkdir -p build/demo assets
.build/release/Scrubby --demo --record build/demo/demo.mov

# Ordered (Bayer) dither stays put from frame to frame, so unchanged areas
# compress away: about 4.5 MB here against 12 MB for error diffusion. A
# full-frame palette keeps the wallpaper gradient from banding.
ffmpeg -y -v error -i build/demo/demo.mov \
  -vf "fps=20,scale=880:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  -loop 0 assets/scrubby-demo.gif

echo "Wrote assets/scrubby-demo.gif ($(du -h assets/scrubby-demo.gif | cut -f1))"

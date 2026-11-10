#!/bin/bash
# install.sh: build Scrubby, put it in /Applications, and launch it.
# The old copy goes to the Trash rather than being deleted.
set -euo pipefail

cd "$(dirname "$0")/.."

die() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

macos="$(sw_vers -productVersion)"
[ "$(printf '%s\n14.0\n' "$macos" | sort -V | head -n1)" = "14.0" ] \
  || die "Scrubby needs macOS 14 (Sonoma) or newer; this is $macos."
command -v swift >/dev/null 2>&1 \
  || die "No Swift toolchain found. Run: xcode-select --install"

./scripts/bundle.sh

APP="/Applications/Scrubby.app"
if pgrep -x Scrubby >/dev/null 2>&1; then
  osascript -e 'quit app "Scrubby"' >/dev/null 2>&1 || pkill -x Scrubby || true
  sleep 0.5
fi
if [ -e "$APP" ]; then
  mv "$APP" "$HOME/.Trash/Scrubby-$(date +%Y%m%d-%H%M%S).app"
fi
cp -R build/Scrubby.app "$APP"
open "$APP"

echo "Installed $APP. Click the critter in the menu bar."
echo "First clean: allow Scrubby under System Settings › Privacy & Security › Accessibility."

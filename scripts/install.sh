#!/bin/bash
# install.sh: build Scrubby, put it in /Applications, and launch it.
# The old copy goes to the Trash rather than being deleted.
set -euo pipefail

cd "$(dirname "$0")/.."
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
echo "First run: allow Scrubby under System Settings › Privacy & Security › Accessibility."

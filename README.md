# Scrubby

Car wash mode for your Mac keyboard. A pixel critter lives in the menu bar; click it, click **Start cleaning**, and every key is ignored (including ⌘Tab, Spotlight, volume, brightness and media keys) until you click **Done cleaning** with your trackpad or mouse. It unlocks by itself after 5 minutes.

## Install

Needs macOS 14+ and the Swift toolchain (`xcode-select --install` is enough).

```bash
scripts/install.sh
```

On first use, allow Scrubby under **System Settings › Privacy & Security › Accessibility**. After a rebuild, toggle it off and on there: each local build has a new signature.

## Limits

- A long press on the power button always shuts down; no app can block that.
- If another app holds Secure Keyboard Entry on, some keys can get past. Scrubby warns you on screen when that happens.

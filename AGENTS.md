# Scrubby

Native macOS menu bar app (Swift/AppKit + SwiftUI, SwiftPM, no Xcode): car wash mode for the keyboard. Click the critter, click Start cleaning, and every key is held back until you click Done with the trackpad or mouse. Styled after its sibling `../merly/` (theme tokens, frosted panel, pixel critter). `CLAUDE.md` is a symlink to this file.

## Commands

- `swift build`: debug build
- `.build/debug/Scrubby --selftest`: key filter and critter checks, no permission or UI needed (exit 1 on failure)
- `.build/debug/Scrubby [--light]`: launch; the panel opens on its own (and again on every relaunch, since a full menu bar can hide the critter behind the notch)
- `.build/debug/Scrubby --clean --unlock-after 5`: start cleaning straight away, auto-unlock after 5 s (QA)
- `scripts/bundle.sh`: release build and assemble `build/Scrubby.app`
- `scripts/install.sh`: bundle, move the old copy to the Trash, install to `/Applications`, launch

## Layout

- `KeyFilter.swift`: which event types and system-defined subtypes get swallowed. Pure, covered by `--selftest`.
- `KeyBlocker.swift`: the HID-level `CGEventTap`.
- `CleaningSession.swift`: idle → cleaning → finished state, permission, 5-minute auto-unlock failsafe.
- `PanelController.swift` / `OverlayController.swift` + `CleaningView.swift`: the menu bar dropdown and the full-screen car-wash overlay (one window per display).
- `Critter.swift`: the 16×16 pixel critter (art grid, outline pass, mood faces). It also renders the app icon via `--write-iconset`.
- `Theme.swift`: tokens copied from Merly's `Theme.swift`. Change them there first.

## Footguns

- **Command Line Tools only.** No XCTest. Never add a test target; extend `SelfTest.swift`.
- **Never change `CFBundleIdentifier`** (`sh.micky.scrubby`). The Accessibility grant hangs off it.
- **Every rebuild drops the Accessibility grant** (ad-hoc signature, new cdhash). Settings still shows Scrubby as on, but `AXIsProcessTrusted()` says no: toggle it off and on. Don't "fix" this with a self-signed identity; see Merly's `docs/specs/distribution.md` for why.
- **Never tap pointer events.** The trackpad and mouse are the only way out of cleaning mode. `KeyFilter` lets aux mouse buttons (system-defined subtype 7) through for the same reason.
- **The tap must stay HID-level** (`.cghidEventTap`). A session-level tap misses ⌘Tab and other system shortcuts.
- **Secure Event Input** (an app's password field, Terminal's Secure Keyboard Entry) hides key events from every tap. Scrubby activates itself to make the other app drop it and warns on the overlay when it stays on.
- The tap re-enables itself on `tapDisabledByTimeout`/`ByUserInput`. If the app hangs or crashes, macOS drops the tap and the keyboard comes back, so the failsafe is the OS, not just the timer.

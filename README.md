# kalaminum

Simple personal time tracking for macOS, in 15-minute slots.

Kalaminum lives in the menu bar. Every quarter hour (:00, :15, :30, :45) a small
panel pops up in the top-right corner asking what you did in the slot that just
ended. Type a few words or click one of your recent activities, and you're done.

## Features

- **15-minute prompts.** They appear without taking keyboard focus, so a prompt
  never swallows what you're typing. Click into the panel when you're ready.
- **One-click answers.** Your 9 most recent activities are buttons (also `⌘1`–`⌘9`).
- **Back-filling.** If earlier slots are empty, for example after a meeting
  away from your desk, the prompt offers to fill them in too. If you ignore a
  prompt, the next one grows to cover both slots instead of stacking a second panel.
- **Day view in the menu bar.** Shows per-activity totals for the day and a
  timeline of every slot. Click a slot (shift-click for a range) and choose
  **Edit…** to change or clear it. Use the arrows to browse earlier days.
- **Pause** reminders for 1 hour, 2 hours or until tomorrow. No prompts appear
  while the Mac is asleep.
- **Open at login** can be turned on from the gear menu.
- **Plain data.** Everything is stored in one readable JSON file:
  `~/Library/Application Support/Kalaminum/entries.json`

## Build & run

Requires macOS 14+ and the Swift toolchain (Xcode or just the Command Line Tools).

```sh
make run       # build build/Kalaminum.app and launch it
make install   # copy to /Applications and launch (recommended for "Open at login")
make test      # unit tests
```

### Development

```sh
# Use a throwaway log instead of your real one, and open the prompt immediately:
KALAMINUM_DATA=/tmp/k.json build/Kalaminum.app/Contents/MacOS/Kalaminum --prompt-now
```

- `Sources/KalaminumCore` contains the pure logic (slot math, storage, totals)
  and is unit-tested.
- `Sources/Kalaminum` contains the SwiftUI/AppKit menu bar app.

With only the Command Line Tools installed, `scripts/env.sh` builds against the
macOS 26 SDK, because the macOS 27 SDK's SwiftUI macros only ship with Xcode. It
also points `swift test` at the swift-testing macro plugin.

## Data format

```json
[
  { "activity" : "Coding", "loggedAt" : "2026-11-02T09:16:03Z", "start" : "2026-11-02T09:00:00Z" }
]
```

Each entry is one 15-minute slot, keyed by its start time (UTC).

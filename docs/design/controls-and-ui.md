# Controls, camera and UI

## Keys

| Key | Action | Since |
|---|---|---|
| WASD / arrows | walk (direct mode); pan the camera (command mode) | M0 / M1 |
| Space | pause / resume | M0 |
| 1 / 2 / 3 | speed 1x / 2x / 3x | M0 |
| Mouse wheel, + / − | zoom | M0 |
| F3 | debug overlay | M0 |
| F5 / F8 | quicksave / quickload | M0 |
| Tab | switch direct ↔ command mode | M1 |
| E | interact with what's in front of you (direct mode) | M1 |
| Left click | select or open the interaction menu; click the ground to walk (command mode) | M1 |
| Esc | cancel, or open the menu (resume, save, load, settings, quit) | M1 |
| F9 | bug report (save + command log + screenshot) | M1 |
| Shift | run (direct mode) | M2 |
| Page Up / Down | view the floor above or below (command mode) | M2 |
| B | build/buy mode | M5 |
| P | phone | M3 |

Keys are physical positions, so they work on QWERTZ.

## Camera

- Direct mode: follows the player; zoom levels 1, 2, 3, 4, 6× (pixel-perfect integers).
- Command mode: free pan by keys, edge scroll or drag; zoom; level paging; a "focus the
  player" key.
- The view shows one floor level at a time: the player's own in direct mode.

## HUD layout (target)

```
┌─────────────────────────────────────────────────────────────────────┐
│ Day 3  Wed 21:40  2x   €37.20        ★★☆☆☆ (wanted)        [debug]  │
│ Kneipe Zum Anker                                                    │
│                                                   notifications     │
│                                                   · Tom insulted you│
│                                                                     │
│ [needs + mood]          [current action + queue]         [phone]    │
└─────────────────────────────────────────────────────────────────────┘
```

- **Needs panel:** 7 bars with colour and trend arrows, plus a mood face; hover a bar for the
  moodlets.
- **Action queue:** the current action with progress, then queued actions, each cancellable.
- **Interaction menu:** a list at the cursor (or above the target in direct mode), with
  unavailable options greyed out and the reason ("Closed", "Not enough money").
- **Person inspector** (click a person in command mode): name, relationship with you, their
  mood, what they're doing, and what they remember about you.
- **Notifications:** short feed lines for important events.
- **Phone** (M3): contacts and messages, jobs, bank, map, property listings (M5), transit
  times (M7).

## Settings (Esc → Settings)

Free will on/off · simulation detail (the fidelity dial: tiered / full) · ageing
(off / slow / normal) · content toggles (weapons) · UI scale · (later) key rebinding, audio.

## UI implementation rules

UI is built in code in `game/ui/`, reads sim state, and sends Commands. It never writes state.
Every screen should be checkable with `tools/screenshot.sh`.

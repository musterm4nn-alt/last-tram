# Controls, camera and UI

## Main menu and character creator (M1)

Starting the game shows the **main menu**: New game, Continue (the latest save), Load (T-0014),
Packs (M5), Quit. **New game** opens the character creator
([character-and-appearance.md](character-and-appearance.md)), then drops you into your flat.
Tools and tests skip the menu with command-line options (`--quickstart`, `--screenshot`, ...).

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
| Shift (hold) | run: twice the walking speed, with WASD and on click-to-walk routes | M1 |
| M | town map (pauses); a minimap is always in the top right | M1 |
| Page Up / Down | climb the stairs you stand on (direct mode); view the floor above or below, and click to walk there (command mode) | M2 |
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

- **Needs panel:** one bar per need (six) with colour and trend arrows, plus a mood face; hover a bar for the
  moodlets.
- **Action queue:** the current action with progress, then queued actions, each cancellable.
- **Interaction menu:** a list at the cursor (or above the target in direct mode), with
  unavailable options greyed out and the reason ("Closed", "Not enough money").
- **Person inspector** (click a person in command mode): name, relationship with you, their
  mood, what they're doing, and what they remember about you.
- **Minimap** (top right): the town around you, with your marker. **M** opens the full map
  with every place's name.
- **Notifications:** short feed lines for important events.
- **Phone** (M3): contacts and messages, jobs, bank, map, property listings (M5), transit
  times (M7).

## Settings (Esc → Settings)

Free will on/off (M1: a button in the Esc menu) · simulation detail (the fidelity dial: tiered / full) · ageing
(off / slow / normal) · content toggles (weapons; **adult content packs**: off by default, with an 18+ confirmation, M6) · UI scale · (later) key rebinding, audio.

## UI implementation rules

UI is built in code in `game/ui/`, reads sim state, and sends Commands. It never writes state.
Every screen should be checkable with `tools/screenshot.sh`.

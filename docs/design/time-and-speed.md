# Time and speed

## The clock

- The sim runs in fixed steps: **20 steps = 1 game minute** (`SimClock.STEPS_PER_GAME_MINUTE`).
- At **1x**, 1 game minute passes per real second, so **a game day lasts 24 real minutes**.
- Day 0 is a **Monday**. New games start Monday 08:00.
- All gameplay rates in data are per game **hour** (for example "hunger −6 per hour"), and
  durations are in game **minutes**.

## Speeds

| Speed | Steps per real second | Use |
|---|---|---|
| Pause | 0 | Think, build, read panels. Commands still queue. |
| 1x | 20 | Normal play. |
| 2x / 3x | 40 / 60 | Getting through routine stretches. |
| Skip (M1) | as fast as possible, capped | While the controlled person is in a long action (sleep, work, jail). It stops at the end of the action or on an interrupt: a need goes critical, someone talks to you, danger nearby, a phone call. |

- Speed is **not sim state**: the sim doesn't know how fast it's being run. That is why
  determinism holds at any speed.
- Speed applies to everything, including walking in direct mode. This is a deliberate
  simplification; revisit after playtesting if 3x walking feels bad.

## Calendar

- 7-day weeks. Monday to Friday are workdays for most jobs; Saturday and Sunday are the
  weekend.
- **Sunday closing:** most shops close on Sunday; the Späti, the Imbiss, bars and the police
  don't. (Very Central European, and a nice pressure point.)
- **Weekly money cycle (M3):** rent and bills are due Monday; wages are paid Friday.
- **Night (22:00–06:00):** quiet hours, fewer witnesses, more crime, bars full.
  **The last tram leaves Altmarkt at about 00:40**, and after that it's walk, night bus or
  taxi (M7). The game is named after that moment.
- Public holidays, seasons and weather: later.

## Ageing

The game is an **ageless sandbox**: no forced ending. Age and life stage exist on every
person, but ageing is a setting: **off** (default), **slow**, or **normal** (days per year
configurable). See [people.md](people.md) for life stages.

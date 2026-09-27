# Simulation tiers (and the "full lives" dial)

**Goal:** the whole town lives all the time, but only the part near the player is simulated
in full detail. It must be possible to switch to **full detail for everyone** later without
rewriting anything.

## One model, different update rates

Every person always has the same complete data: needs, action queue, memories,
relationships, money, job, home. A tier only decides **how often and how precisely** that
data is updated.

| Tier | Who | How they're simulated |
|---|---|---|
| **Active** | within `active_radius` of the player (default 40 cells), in the same building, on screen, or involved with an active person (a police chase, a conversation) | Every step: real movement and pathfinding, per-minute needs, full interactions, line-of-sight witnessing |
| **Background** | everyone else | Event-driven and abstract: each person has a `next_wake_tick`. On waking, their current action is resolved in bulk, and autonomy picks the next one using the same interaction data. Travel is a time estimate; the person is "at lot X" or "travelling from A to B until T". Social encounters and crimes between co-located people are rolled per time window and produce the same memories, relationship changes and events. |

Needs decay linearly, so bulk decay over *n* minutes equals *n* per-minute decays. The main
differences between tiers are movement detail and encounter granularity.

## Moving between tiers

- **Promotion** (background → active): the person is placed where they would plausibly be. At
  the lot, they go to a sensible spot (a use slot of their current action). When travelling,
  they're placed along the route by elapsed time on a walkable cell. They continue their
  current action.
- **Demotion** (active → background): the current action becomes abstract, and the remaining
  duration and travel time are estimated.
- Tier changes are checked every few game minutes, with hysteresis (promote at 40 cells,
  demote at 50) so nobody flickers.

## The fidelity dial

Settings (saved with the game, changeable any time):
- `tiers.mode`: `"tiered"` (default) or `"full"` (everyone active: "full lives").
- `tiers.active_radius`, `tiers.demote_radius`.
- `tiers.background_max_interval_minutes`: an upper bound on how long a background person
  sleeps between updates.

Switching to "full lives" means setting `mode = "full"`. The only question is performance,
and with a hand-made town (tens to low hundreds of residents) it may simply work.

## How we know it's right (tests, M2)

- **Equivalence:** simulate the same town for 3 days in `full` and in `tiered` mode, and
  compare aggregates within tolerances: average needs, work attendance, number of social
  interactions, money, crimes.
- **Round trip:** repeated promotion and demotion never puts a person in a wall, loses an
  action, or breaks a reservation.
- **Budget:** background cost per resident per game hour stays under a set limit, and
  `tools/simrun.sh` reports it.

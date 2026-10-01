---
id: T-0042
title: Simulation tiers and the 'full lives' dial
status: done
milestone: M2
size: L
owner: builder
depends_on: [T-0036, T-0039]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
People far from the player are simulated more cheaply, people near the player in full
detail, and a setting ("Full lives" in the Esc menu) switches everyone to full detail.
v1 per D28: the background tier keeps the same data and rules, but walking and action steps
update once per game minute instead of every step.

## Scope
Create `sim/world/tier_settings.gd`, `sim/systems/tier_system.gd`,
`sim/commands/set_tier_mode_command.gd`, `tests/sim/test_tiers.gd`. Change
`sim/world/world.gd` (`tiers`, saved), `sim/people/person.gd` (`background`),
`sim/systems/action_system.gd` (`step_person`; background on the minute),
`sim/systems/movement_system.gd` (background walks a minute at a time), `sim/sim.gd`,
`sim/core/command_registry.gd`, the save validators, `game/ui/pause_menu.gd` (Full lives),
`tools/sim_runner.gd` (`--tiers`, `--active-radius`, background counts), the design doc,
`docs/decisions.md` (D28).
**Out of scope:** event-driven abstract background (next_wake_tick, travel estimates,
encounters rolled per window). D28 keeps it for a bigger town.

## Specification
- `TierSettings` (saved in the world): mode `tiered` | `full`, active_radius 40,
  demote_radius 50.
- `TierSystem` (first, every 2 minutes): the player is always active, and everyone is in
  "full". Otherwise background → active within active_radius, active → background beyond
  demote_radius (cells, +10 per floor apart). Anyone an active person is doing something to is
  active. Emits `tier_changed`.
- Background people: ActionSystem runs their step in `on_minute`; MovementSystem moves them a
  minute's walk along their path in `on_minute`. Needs, social, routines and free will were
  already per minute, so they're unchanged.
- `SetTierModeCommand`; Esc menu "Full lives: On/Off".

## Acceptance criteria (`tests/sim/test_tiers.gd`)
- [x] Near people are active, far ones background; the player always active.
- [x] Hysteresis between the radii; full mode makes everyone active.
- [x] Someone an active person talks to becomes active.
- [x] Round trip: flipping everyone between tiers every 7 minutes for a day never puts anyone
  in a wall, loses an action's target or lets two people hold one slot.
- [x] Equivalence: 2 days full vs tiered (radius 10): average needs within 4, and social
  exchanges, sleeps and meals within 25%.
- [x] Tier settings and flags survive saving. Screenshot `out/t0042.png` (Esc menu).
- [x] `tools/check.sh` passes.

## Implementation notes
- `tools/simrun.sh --days=3`, full vs `--active-radius=10`: residents' average hunger 78.3 vs
  79.3, social 89.0 vs 88.6, with similar action counts (jokes 508 vs 475, sleeps 85 vs 88,
  meals 295 vs 292). Cost 0.109 vs 0.069 ms per step (−37%).
- With the default 40-cell radius, almost all of the 72×44 Altstadt is active, so tiers matter
  little until the town grows (M7).
- Verified: `tools/check.sh` 459 passed, 0 failed.

## Questions

## Review feedback

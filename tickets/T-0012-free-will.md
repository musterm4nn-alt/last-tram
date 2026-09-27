---
id: T-0012
title: Autonomy scoring: what would this person like to do now?
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0007, T-0011]
builder:
review_rounds: 0
---

## Goal
The sim can rank what a person could do next, the way The Sims does: each interaction on a
nearby object is scored by how badly the person needs what it advertises, minus how far
away it is, and one of the best few is picked with a little randomness. This ticket is the
scoring only (pure functions and tests); T-0025 makes the idle player actually act on it.

## Read first
- `docs/design/actions-and-autonomy.md` → "Autonomy (utility AI)"
- As merged: `sim/content/interaction_def.gd` (`advertise: Dictionary[String, float]`),
  `sim/content/need_def.gd` (`urgency_weight`), `data/needs.json`, `data/interactions/*.json`,
  `sim/actions/interactions.gd` (`offered_by`, `slot_taken`), `sim/world/world_object.gd`
  (`slot_count`, `slot_cell`), `sim.nav.find_path(from, to)`
- `sim/core/sim_rng.gd` (a `RandomNumberGenerator` per named stream)

## Scope
Create `sim/ai/utility.gd` (`Utility`), `sim/ai/autonomy.gd` (`Autonomy`),
`tests/sim/test_autonomy_scoring.gd`.
**Out of scope:** running autonomy in the sim, free-will settings, input (T-0025);
personality, mood and routines (M2).

## Specification

### `Utility` (`extends RefCounted`, static, pure)
```gdscript
## ((100 - value) / 100)² × weight: 0 when the need is full, `weight` when it is empty.
## `value` is clamped to 0..100 first.
static func urgency(value: float, weight: float) -> float
## Σ over the interaction's advertised needs of urgency(need value, need weight) ×
## min(advertised amount, 100 - need value). Capping by the room left in the need stops a
## nearly rested person from wanting 80 energy of sleep. Needs the person lacks count as 100
## (full); unknown need ids are skipped.
static func need_score(person: Person, def: InteractionDef, content: ContentDB) -> float
```

### `Autonomy` (`extends RefCounted`, static)
```gdscript
## Each step of distance to a slot costs this much score.
const TRAVEL_COST_PER_CELL: float = 0.1
## Options scoring below this are ignored (the person is content and does nothing).
const MIN_SCORE: float = 3.0
## Random noise added to each score before picking, 0..NOISE.
const NOISE: float = 1.0
## How many of the best options the final pick chooses among.
const TOP_N: int = 3
## Objects whose origin is within this many cells (Chebyshev distance, same level) count.
## M2 replaces this with the person's lot and its access rules.
const SEARCH_RADIUS: int = 12

## Every option the person could take now, in object id order, then content order:
## [{"object_id": int, "interaction_id": String, "score": float, "cells": int}].
## Objects count if their origin is on the person's level and within SEARCH_RADIUS
## (max(|dx|, |dy|) <= SEARCH_RADIUS). For each
## interaction the object offers: cells = the path length to its nearest free, walkable
## slot (0 if the person stands on one; the option is skipped if no free slot is
## reachable); score = Utility.need_score(...) - TRAVEL_COST_PER_CELL × cells.
static func candidates(sim: Sim, person: Person) -> Array[Dictionary]

## Adds rng.randf() × NOISE to each score (in list order), drops options below MIN_SCORE,
## keeps the TOP_N best (ties: earlier in the list), and picks one with probability
## proportional to its noisy score. Returns {} when nothing is left. Uses `rng` only.
static func choose(options: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary
```
"Free" means not `Interactions.slot_taken(sim, object_id, index, person.id)`.

## Acceptance criteria (`tests/sim/test_autonomy_scoring.gd`)
- [ ] `urgency`: 100 → 0, 0 → the weight, 50 with weight 1.2 → 0.3, and values outside
  0..100 are clamped.
- [ ] `need_score`: sleep at energy 70 = 0.09 × 30 = 2.7 (capped by the room left); at
  energy 20 = 0.64 × 80 = 51.2; grab_snack at hunger 50 (weight 1.2) = 0.3 × 25 = 7.5.
- [ ] `candidates` in a new game (`SimFactory.new_game(content(), 1)`), player at the spawn
  with hunger 30 and everything else 100: the grab_snack and cook_meal options are present
  with the expected `cells` (compare with `sim.nav.find_path(...).size()` to the slot) and
  scores. A fridge placed 13 or more cells away (e.g. on the pavement at (36, 22)) gives no
  option.
- [ ] `candidates` skips an option whose only slot is taken by another person, or cannot be
  reached (block the fridge's slot with a placed object).
- [ ] `choose`: returns {} when every score is below MIN_SCORE; with a fixed-seed
  `RandomNumberGenerator`, over 1000 picks from five options it only ever returns one of the
  three best, and returns the best one most often; the same seed gives the same sequence.
- [ ] A hungry person prefers cooking to a snack when both are equally far (cook advertises
  60, the snack 25), and a snack when only the fridge is in the place.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback

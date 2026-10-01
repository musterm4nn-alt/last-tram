---
id: T-0034
title: Residents and households - about 30 generated neighbours with homes
status: done
milestone: M2
size: L
owner: builder
depends_on: [T-0031, T-0033]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
A new game fills the 15 neighbour homes (T-0031) with generated adults: singles, couples and
flatmates (households). They get names, looks, outfits and personalities from the same model
as the player, and each one starts at home. The player is a household of one.

## Read first
- `docs/design/people.md` → "Households (M2)", "Content rules"
- As merged: `sim/sim_factory.gd` (`new_game`, `_spawn_player`), `sim/people/character_spec.gd`
  (`random`), `sim/world/world.gd` (saving entities), `sim/world/lots.gd`

## Scope
Create `sim/people/household.gd`, `sim/people/resident_generator.gd`,
`tests/sim/test_residents.gd`. Change `sim/sim_factory.gd`, `sim/world/world.gd`,
`sim/people/person.gd`, `sim/save/save_validator.gd`, `sim/save/save_person_validator.gd`.
**Out of scope:** free will tuning for 30 people (T-0035), routines (T-0036), relationships
between household members (T-0037), the population changing over time.

## Specification
- `Household` (entity, `World.households: Dictionary[int, Household]`, saved as
  `"households"`, old saves → none): `id`, `kind` (`"single"`, `"couple"`, `"flatmates"`),
  `member_ids: Array[int]`, `home_lot_id`. `Person.household_id: int` (saved, default 0).
  Every member's `home_lot_id` is the household's lot, so `Lots.may_enter` admits them.
- `SimFactory.spawn_person(sim, cell, spec) -> Person` (public; `_spawn_player` uses it).
- `ResidentGenerator.populate(sim, skip_lot_ids)`: all draws from `sim.rng.stream("generation")`.
  For each private home lot (in id order) not skipped: kind by weight (single 30, couple 40,
  flatmates 30; flatmates are 2 or 3 people). Members are `CharacterSpec.random`. A partner's
  age is within ±8 years of the first member's (and never below 18), and partners share a
  last name half the time. Each member spawns on a distinct walkable cell of the home's place.
- `SimFactory.new_game`: after lots, the player's household (single, the player's lot), then
  `populate(sim, [player home lot])`. Object, player and lot ids don't change.
- Validation: households (ids, members, lot, kind) and `household_id`.

## Acceptance criteria (`tests/sim/test_residents.gd`)
- [x] Seed 1 creates 20–40 residents in 15 households, one per neighbour home; every resident
  lives in their household's home, stands on a walkable cell inside it, and no two share a cell.
- [x] Over 20 seeds, every person is 18 or older and every spec validates.
- [x] The same seed gives the same residents; another seed gives others.
- [x] Couples are two people within 8 years of each other; flatmates are 2–3.
- [x] Residents may enter their own home and not other homes; the player's household is
  just the player.
- [x] Households and `household_id` survive save/load; old saves load with none.
- [x] `tools/check.sh` passes; `tools/simrun.sh --days=1` still runs; screenshot `out/t0034.png`
  of an upper floor with residents.

## Implementation notes
- `Household`, `ResidentGenerator`, `SimFactory.spawn_person` as specified. Seed 1: 25
  residents in 15 households (+ the player's), between 20 and 40 over the tested seeds.
- Found and fixed along the way:
  - Godot's JSON parser drops some floats by an ulp, so 30 people broke "save and continue =
    uninterrupted". Fixed separately as **T-0051** (D26).
  - **Speed.** With 30 people, a simulated day took 5.4 s (was 0.2 s) and the suite 82 s. Three
    changes (D27):
    1. Free will that finds nothing waits `AutonomySystem.RETRY_MINUTES` (5) before looking
       again (`Person.autonomy_retry_tick`, saved). 86% of checks found nothing.
    2. `ActionSystem` checks a performer's slot and target fully once per personal minute,
       before granting benefits, instead of every step. Only input or a path can move a
       performer, and both are still checked every step.
    3. `ContentDB.place_at` uses a per-level cell index; `World.lot_id_for_place` caches
       place → lot.
    Now 1.6 s per day (0.055 ms per step, about 1 ms per real second at 1×) and 29 s for
    the suite.
- Test updates for a populated town (not weakened): `test_free_will.gd` counts only the
  player's choices and finished actions; `test_bug_report.gd` moves everyone's
  `last_input_tick` with the clock it rewinds, and reads reports with `Ser.parse_json`.
- Later (T-0045): flatmates are 2 people, and households only go where the beds fit them.
- Verified: `tools/check.sh` 398 passed, 0 failed (`test_residents.gd`, 8 tests).
  `tools/simrun.sh --days=1` OK. Screenshot `out/t0034.png`: residents in their first-floor
  flats at 08:30.

## Questions

## Review feedback

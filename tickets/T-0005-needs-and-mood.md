---
id: T-0005
title: Needs and mood
status: review
milestone: M1
size: M
owner: builder
depends_on: []
builder: OpenCode / Muse Spark 1.3 Free
review_rounds: 0
---

## Goal
Every person has the seven needs (hunger, energy, bladder, hygiene, fun, social, comfort)
that decay over game time, plus a mood computed from them. Nothing refills them yet (T-0006).

## Read first
- `docs/design/people.md` → "Needs (M1)", "Mood"
- `docs/cookbook.md` → "Add a new kind of content", "Add a system", "Add a field to Person"

## Scope
Create `data/needs.json`, `sim/content/need_def.gd`, `sim/people/mood.gd`,
`sim/systems/needs_system.gd`, `tests/sim/test_needs.gd`.
Change `ContentDB`, `Person` (needs, saved), `SimFactory._spawn_player` (initial needs),
`Sim.default_systems()`, `tools/sim_runner.gd` (report), `game/ui/debug_overlay.gd`
(one line with the player's needs).
**Out of scope:** the HUD needs panel (T-0008), moodlets (M2), anything that refills needs.

## Specification
- `data/needs.json`: `{"needs": [{"id", "name", "decay_per_hour", "start", "urgency_weight",
  "critical_below"}]}` with the seven needs in the order of the design doc. Values:
  decay/h hunger 6, energy 4.5, bladder 12, hygiene 4, fun 6, social 4, comfort 8. Start
  values 80 (bladder 70). urgency_weight 1.0 (bladder 1.5, hunger 1.2). critical_below 15.
- `NeedDef`: those fields, typed. `ContentDB.needs: Array[NeedDef]` (file order) and
  `ContentDB.need(id) -> NeedDef`. Validate: unique ids, decay ≥ 0, 0 ≤ start ≤ 100,
  0 ≤ critical_below ≤ 100, weight > 0.
- `Person.needs: Dictionary[String, float]`: saved; on load, missing needs get their `start`
  value (so old saves load, and adding a need later needs no migration).
- `NeedsSystem.on_minute()`: for every person and need,
  `value = clampf(value - decay_per_hour / 60.0, 0.0, 100.0)`. When a value crosses **below**
  `critical_below` (it was ≥ before this minute), emit `&"need_critical"`
  `{"person_id", "need"}` once.
- `Mood.compute(person: Person, content: ContentDB) -> float` (static, pure, **not saved**):
  ```
  mood = 20
  for each need with value v:  if v < 50:  mood -= ((50 - v) / 50)² × 30 × urgency_weight
  return clampf(mood, -100, 100)
  ```
  and `Mood.label(mood) -> String`: ≥ 20 "Fine", ≥ 0 "Okay", ≥ −40 "Uneasy", else
  "Miserable". (Moodlets add to this in M2.)
- System order: `[MovementSystem, NeedsSystem]` (T-0006 will insert ActionSystem).

## Acceptance criteria (`tests/sim/test_needs.gd`)
- [ ] After exactly 60 game minutes each need dropped by its `decay_per_hour` (tolerance
  1e-6).
- [ ] Needs never go below 0 (run 3 game days) and never above 100.
- [ ] `need_critical` fires exactly once when crossing the threshold, not every minute after.
- [ ] Mood: all needs at 100 → 20 ("Fine"); one need at 0 lowers mood by 30 × weight;
  more empty needs → lower mood (monotonic check).
- [ ] Needs survive save/load; "save mid-run equals uninterrupted run" holds with needs.
- [ ] Loading the v1 fixture save (which has no needs) gives everyone start values.
- [ ] Content validation rejects a broken need definition (a fixture in
  `tests/fixtures/content_broken/`).
- [ ] `tools/simrun.sh --days=1` prints the player's needs each report line; paste a sample
  in your notes.
- [ ] `tools/check.sh` passes.

## Implementation notes

Implemented exactly to spec.

Created:
- `data/needs.json`: seven needs in design-doc order (hunger, energy, bladder, hygiene,
  fun, social, comfort) with the specified decay/start/weight/critical values.
- `sim/content/need_def.gd` (`NeedDef`, typed fields, `##` docs).
- `sim/people/mood.gd` (`Mood.compute` static pure + `Mood.label` with the 20/0/-40
  thresholds, clamped to -100..100).
- `sim/systems/needs_system.gd` (`on_minute` decays `decay_per_hour / 60`, clamps 0..100,
  emits `&"need_critical"` once when crossing from >= to < `critical_below`).
- `tests/sim/test_needs.gd`: 12 tests covering all acceptance criteria.
- `tests/fixtures/content_broken/needs.json`: duplicate id + negative decay + start 150 +
  weight 0 + critical -5, for the validation test.

Changed:
- `sim/content/content_db.gd`: `needs: Array[NeedDef]`, `need(id)`, `_load_needs()` with
  validation (unique ids, decay >= 0, start 0..100, critical 0..100, weight > 0).
- `sim/people/person.gd`: `needs: Dictionary[String, float]`, saved in `to_dict()`,
  loaded in `from_dict()` (missing `needs` key reads as empty).
- `sim/world/world.gd` (not listed in scope, but required): `World.from_dict()` fills any
  missing need with its `start` value from content, so the v1 fixture (no needs) loads
  and future new needs need no migration.
- `sim/sim_factory.gd`: `_spawn_player()` sets every need to its `start` value.
- `sim/sim.gd`: `default_systems()` is now `[MovementSystem, NeedsSystem]`.
- `tools/sim_runner.gd`: `_report()` now includes `needs hunger=.. ...` and mood on every
  report line.
- `game/ui/debug_overlay.gd`: one new UI line with the player's needs plus mood
  (`needs hunger 80 ... mood 20 (Fine)`).

Verification:
- `tools/check.sh`: 55 passed, 0 failed (`LAST_TRAM_TESTS: PASSED`), including 12 new
  `test_needs.gd` tests and the existing save/content/lint suites.
- `tools/simrun.sh --days=1` prints needs every line. Sample:
  `[Mon 08:00] people 1 | player (50.5, 26.5) Haus 12, ground floor | needs hunger=80.0 energy=80.0 bladder=70.0 hygiene=80.0 fun=80.0 social=80.0 comfort=80.0 | mood 20.0 (Fine)`
  `[Mon 12:00] people 1 | player (50.5, 26.5) Haus 12, ground floor | needs hunger=56.0 energy=62.0 bladder=22.0 hygiene=64.0 fun=56.0 social=64.0 comfort=48.0 | mood 5.8 (Okay)`
  `[Tue 08:00] people 1 | player (50.5, 26.5) Haus 12, ground floor | needs hunger=0.0 energy=0.0 bladder=0.0 hygiene=0.0 fun=0.0 social=0.0 comfort=0.0 | mood -100.0 (Miserable)`
  Full 25-line log ends with `LAST_TRAM_SIMRUN: OK`.
- No save-version bump (missing needs default to `start`, per spec). No visual change, so
  no screenshot.

Left out / uncertain: nothing. Moodlets, refills, and HUD panel are out of scope per ticket
(T-0006/T-0008/M2).

## Questions

## Review feedback

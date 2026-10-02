---
id: T-0066
title: Eviction, sleeping rough, and moving into empty flats
status: done
milestone: M3
size: L
owner: builder
depends_on: [T-0062, T-0063]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Unpaid rent has consequences. After three weeks behind, a household is evicted: they lose the
flat, sleep rough on a park bench or the promenade, and feel it ("Evicted", for days). It can
be recovered from: anyone homeless who can pay two weeks' rent moves into an empty flat, and
flats that stay empty get newcomers. The player can be evicted too, and can find a new flat on
the phone.

## Read first
`docs/design/jobs-and-economy.md` → Housing; `sim/economy/housing.gd` (T-0062);
`sim/people/resident_generator.gd`; `sim/ai/autonomy.gd` (`errand`); `game/ui/phone/`.

## Scope
New: `sim/economy/moving.gd`, `sim/commands/rent_flat_command.gd`,
`game/ui/phone/housing_app.gd`, `data/interactions/housing.json`, `tests/sim/test_moving.gd`,
fixture `v13_basic.json`. Change: `economy.json` (+ `EconomyDef`, loader), `moodlets.json`,
`Lot` (`vacant_since_day`), save v13, `InteractionDef`/loader (`homeless_only`),
`Requirements` (`has_home`, hidden), `Autonomy.errand`, `EconomySystem`,
`ResidentGenerator` (newcomers), `Money` (one resident's start money), `CommandRegistry` and
the save validator's command list, `Phone`, `Hud` (notices), `PersonInspector` (no home),
`sim_runner.gd` (housing line). **Out of scope:** a promenade sleeping spot (benches only),
landlords, deposits, furniture moving, the town check's rules.

## Specification
- `economy.json` → `"housing": {"evict_after_weeks": 3, "move_in_weeks": 2, "move_in_hour": 10,
  "vacant_days": 7}` (`EconomyDef.evict_after_weeks`, `move_in_weeks`, `move_in_hour`,
  `vacant_days`; validated ≥ 1, hour 0..23).
- `Lot.vacant_since_day: int = -1` (saved; v13 migration sets -1 on every lot).
- **`Moving`** (static): `empty_homes(sim) -> Array[Lot]` (private home lots nobody lives in,
  id order); `move_in_cost(sim, lot) -> int` (`move_in_weeks` × the place's rent);
  `evict_overdue(sim)` (Monday, right after rent: every household whose lot is
  `evict_after_weeks` or more behind loses it: arrears written off, `home_lot_id = 0` for the
  household and its members, groceries 0, moodlet `evicted`, memory "evicted", event
  `&"evicted" {household_id, lot_id}`, the lot's `vacant_since_day` = today);
  `rent_flat(sim, person, lot) -> String` ("" or `not_available`, `owe_rent`, `cant_afford`,
  `too_small`; the person's whole household moves, paying the cost from the members' banks
  as "rent"; the old home becomes vacant; event `&"moved_in" {household_id, lot_id,
  newcomers: false}`); `daily(sim)` (at `move_in_hour`, each empty home in id order: mark
  `vacant_since_day` if unset, else give it to the first homeless non-player household that
  `rent_flat` accepts, else after `vacant_days` empty, newcomers move in:
  `ResidentGenerator.newcomers(sim, lot)`, with start money, groceries and benefit
  registration like a new town, event `&"moved_in"` with `newcomers: true`).
- **Sleeping rough**: `sleep_rough` (benches, routine "sleep", `homeless_only`, worse than a
  bed: less energy per hour, comfort and hygiene fall, moodlet `slept_rough`).
  `Requirements` reason `has_home` (hidden from menus) for people with a home. For people
  without one, `Autonomy.errand` counts it, so benches anywhere in town are options.
- **Player**: phone app "Housing": your home and rent (or "No home"), then the empty flats
  with rent, beds and the move-in cost, each with "Rent this flat" (`RentFlatCommand`,
  type `rent_flat`). HUD notices for evicted, moved in, and refusals.

## Acceptance criteria
- [x] Three unpaid weeks evict; arrears written off; moodlet, memory, event →
  `test_three_unpaid_weeks_evict`.
- [x] People without a home sleep rough on a bench; people with one never do →
  `test_homeless_sleep_rough`.
- [x] A homeless household with money moves into an empty flat and pays →
  `test_homeless_with_money_move_in`.
- [x] A flat empty for a week gets newcomers with money and groceries →
  `test_empty_flat_gets_newcomers`.
- [x] The player can rent an empty flat through the command; refusals give reasons →
  `test_player_rents_a_flat`, `test_housing_app_lines` (tests/game).
- [x] Save/load keeps it (vacancy, homelessness) and old saves migrate →
  `test_moving_survives_save`, fixtures load.
- [x] `tools/simrun.sh --days=7 --check-m2` unchanged on seeds 1–6 (nobody can be evicted in
  a week).

## Implementation notes
Built and self-reviewed by Opus in a cloud session (2 October 2026).

**In game terms:** three unpaid rent Mondays and a household is out: the debt is written off,
the fridge stays, they feel "Evicted" for three days and remember it. People with no home
sleep on park benches ("Slept rough"), eat out and still go to work. Every day at 10:00 an
empty flat goes to a homeless household that can pay two weeks' rent up front; a flat empty
for a week gets newcomers (generated like a new town's residents, with money and groceries).
The phone has a **Housing** app: your home, rent and debt (or "No home"), and the empty flats
with "Rent this flat". Notices for being evicted, moving in, and refusals.

**Files:** `sim/economy/moving.gd` (`Moving`), `sim/commands/rent_flat_command.gd`,
`data/interactions/housing.json` (`sleep_rough`, `homeless_only`), `Requirements` (`has_home`,
hidden), `Autonomy.errand` (benches for the homeless), `EconomySystem`, `ResidentGenerator.newcomers`,
`Money.give_resident_start`, `Lot.vacant_since_day` (save v13, fixture `v13_basic.json`),
`economy.json` "housing", moodlets `evicted` and `slept_rough`, `game/ui/phone/housing_app.gd`,
`Phone`, `Hud`, `PersonInspector` ("no home"), the housing line in `sim_runner.gd`.

**Verification:** `tools/check.sh` 612 passed. `tests/sim/test_moving.gd` (6 tests, one per
criterion) and `test_housing_app_lines`. A 28-day run (seed 1) evicts nobody: wages, benefit
and pensions cover the rent (housing line: 0 behind, 0 homeless, 0 empty). A probe evicting
a household and running two days: the resident worked, ate a Döner, slept rough on a bench,
and their hygiene and comfort hit 0 (nowhere to wash until the Waschsalon, T-0074).
New towns are unchanged (no new random draws), so the seven-day checks are as before.

**Left out:** a promenade sleeping spot (benches are enough), carrying furniture, the
screenshot (Housing app; take it on the Mac with the phone open, `P` → Housing).

## Questions

## Review feedback

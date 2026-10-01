---
id: T-0066
title: Eviction, sleeping rough, and moving into empty flats
status: draft
milestone: M3
size: L
owner: builder
depends_on: [T-0062, T-0063]
builder:
review_rounds: 0
---

## Goal
Unpaid rent has consequences. After three weeks behind, a household is evicted: they lose the
flat, sleep rough on a park bench or the promenade, and feel it ("Evicted", for days). It can
be recovered from: anyone homeless who can pay two weeks' rent moves into an empty flat, and
flats that stay empty get newcomers. The player can be evicted too, and can find a new flat on
the phone.

## Read first
`docs/design/jobs-and-economy.md` → Housing; T-0062 (arrears); `sim/ai/routines.gd`
(`home_route`, `at_home`); `sim/people/resident_generator.gd` (`_move_in`).

## Design (draft: detailed when its dependencies are merged)
- `economy.json`: `evict_after_weeks` 3, `move_in_weeks` 2 (rent up front), `vacant_days` 7.
- Eviction (`EconomySystem`, Monday 08:00 after rent): the arrears are written off (no ledger
  change, nobody was paid), members get `home_lot_id = 0`, the household keeps existing
  with `home_lot_id = 0`, plus an "evicted" moodlet (−40, 3 days), a memory, an `evicted`
  event and a notice.
- Sleeping rough: a `sleep_rough` interaction (routine "sleep") on benches and a new
  promenade spot, worse than a bed (comfort and hygiene costs). With no home, sleep goes
  there and `home_route` returns nothing.
- Moving in: Monday 10:00, an empty flat goes to a homeless household that can pay
  `move_in_weeks` of rent (paid at once). A flat empty for `vacant_days` gets a newcomer
  household (`_move_in`, the `moved_in` event; new people get money and jobs like at
  generation).
- The player: a Housing app on the phone lists empty flats (rent, size) with "Rent this flat"
  (`RentFlatCommand`).

## Acceptance (sketch)
- Three unpaid weeks evict; evicted people sleep rough and are unhappy; a homeless person with
  money moves into an empty flat; newcomers fill a flat that stays empty; the player can
  rent a new flat. Save/load keeps all of it.

## Implementation notes

## Questions

## Review feedback

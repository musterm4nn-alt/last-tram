---
id: T-0098
title: Trespassing and burglary
status: done
milestone: M4
size: M
owner: builder
depends_on: [T-0096]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Two more crimes for the player: going where you have no business (someone else's flat, a shop
after hours) is trespassing, and searching someone else's wardrobe for valuables is a
burglary that takes part of their savings.

## Docs
[docs/design/crime-and-police.md](../docs/design/crime-and-police.md) "Crimes"

## Scope
- `sim/crime/trespass.gd` (new `Trespass`: `check`, `forbidden`, `passing_through`,
  `doorway`), called first in `PoliceSystem.on_minute`; `Person.on_lot_id` (saved).
- `InteractionDef.trespass` (`"trespass": true`, loader validated) and the Requirements rule
  `not_a_break_in` (hidden); `"burgle"` ("Search for valuables") at wardrobes.
- `CrimeDef.steal_account` (`"account"` in `steals_cash`: cash or bank); burglary takes 20%
  of the bank, at most €200, from `Crimes.home_victim` (the home's richest resident);
  `Money.steal(..., account)`; the `stolen` event carries `crime_id`.
- Notices: "You're trespassing", "You found €X at Name's", "Nothing worth taking",
  "Someone broke into your home: €X gone".

**Out of scope:** jail (T-0099), residents burgling (free will never offers objects on lots
they may not enter), locked doors, stolen items, victims noticing later.

## Acceptance criteria
- [x] Content → `test_trespass_and_burglary.gd: test_burglary_content`, `test_bad_trespass_content_and_saves_are_rejected`
- [x] Someone else's home: trespassing once per visit, with a notice →
  `test_entering_someone_elses_home_is_trespassing_once_per_visit`
- [x] Your own home and open shops are fine → `test_own_home_and_open_shops_are_fine`
- [x] Closed shops: walking in is, staying on isn't; 30 minutes' grace after closing →
  `test_a_closed_shop_is_off_limits_but_staying_on_is_fine`, `test_just_after_closing_is_not_trespassing_yet`
- [x] Staff and officers on a call → `test_staff_and_officers_on_a_call_may_go_in`
- [x] Passing through and doorways don't count → `test_walking_through_is_not_trespassing_but_stopping_is`,
  `test_standing_in_the_doorway_is_not_trespassing`
- [x] Break-ins only in someone else's home; other actions there stay "private" →
  `test_break_ins_only_in_someone_elses_home`
- [x] A burglary takes 20% of the savings, at most €200 → `test_burgling_takes_part_of_the_savings`
- [x] Notices → `test_hud_place.gd: test_trespass_and_burglary_notices`
- [x] Residents don't trespass by accident: 7-day runs on seeds 1-4 show 0 trespassing
  (`tools/simrun.sh`), and M2 and staffing still pass

## Implementation notes
Built and reviewed by the architect. `tools/check.sh` passes.
- The first version (any step onto a forbidden lot) gave ~14 trespasses a day by residents:
  routes cut through closed shops, upstairs neighbours of Haus 3 cross its ground-floor flat
  (the flat's lot covers the way to the stairs), customers arrived just after closing, and
  people chatted in doorways. Hence the four exemptions (passing through, doorways, 30
  minutes' grace, staff). After them: 0 in a week on seeds 1-4.
- A doorway is "walkable and blocks sight" (only the door terrain today), so no terrain id is
  hard-coded.
- Old saves have no `on_lot_id`: everyone starts at 0, so someone standing in a closed shop
  at load would count once. Rare enough to accept; no save version bump.
- No screenshot: the new menu line and notices are text (tested).

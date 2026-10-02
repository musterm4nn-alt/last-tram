---
id: T-0062
title: Rent, bills, benefit and pensions - the weekly cycle
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0061]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Living costs money. Every flat has a weekly rent, due on Monday morning from the bank and
shared equally by the household, plus a small bill for power and internet. What isn't paid
becomes arrears, with a reminder. The state keeps people afloat: unemployment benefit (a base
amount plus help with the rent) and pensions are paid on Monday before the rent. Eviction
after three weeks behind comes in T-0066.

## Read first
D29; `docs/design/jobs-and-economy.md` → Weekly cycle, Housing; `sim/world/lot.gd`,
`sim/people/household.gd`, T-0061's `EconomySystem`.

## Design (draft: detailed when its dependencies are merged)
- Rent is content: a home place's `"rent"` (cents per week) in `district.json`, from about
  €100 (small flats) to €210 (Haus 12, the player's). Arrears are state: `Lot.arrears` and
  `Lot.weeks_behind`, saved (with a version bump if the shape needs it).
- `economy.json`: `bills_week`, `benefit_week`, `housing_cap`, `pension_week`, and the cycle's
  hours (benefit and pension Monday 06:00, rent Monday 08:00).
- Monday 06:00: residents who are unemployed, registered and under 67 get the benefit base
  plus their rent share up to `housing_cap`; people aged 67+ get the pension. NPCs are
  registered at generation; the player registers on the phone (T-0064), so until then
  `Person.benefit_registered` is false for them.
- Monday 08:00: each member pays `rent / members` and `bills / members` with
  `Money.charge(…, "rent")` / `"bill"`. Anything unpaid goes into arrears, and a week with
  any unpaid rent counts as a week behind. A later full payment also pays off arrears; at
  zero arrears, `weeks_behind` resets.
- `rent_unpaid {household_id, lot_id, owed, weeks_behind}` → for the player's household,
  a HUD notice "Rent: €58.00 unpaid (1 week behind)".
- simrun: rent paid and owed, households behind, benefit and pensions paid.

## Acceptance (sketch)
- Exact rent shares; arrears and weeks behind; benefit covers an unemployed resident's rent
  share; pensions; the order of Monday's payments.
- 14-day run: no household falls behind without a reason that shows in the report, the ledger
  balances, and `--check-m2` passes.

## Implementation notes
- Built from the draft: weekly rent per home in `district.json` (`PlaceDef.rent`, required
  for homes and only for them), `Lot.arrears`/`weeks_behind`, `Person.benefit_registered`
  (residents yes, the player no), save v8 (`_v7_to_v8`, `v8_basic.json`), `Housing`
  (`sim/economy/housing.gd`: `pay_benefits`, `collect_rent`, `rent_share`), the Monday steps
  in `EconomySystem`, `economy.json` "week", `bills_week`, `benefit_week`, `housing_cap`,
  `pension_week`. HUD: "Rent: €205.00 unpaid (1 week behind)". simrun `housing:` line.
- `test_world_validation.gd`'s sample district home gained a rent (now required).
- Verified: `tools/check.sh` 545 passed, 0 failed (`test_rent.gd`, 5 tests).
  `tools/simrun.sh --days=14 --check-m2` PASSED on seeds 1–3: rent €4,190 and bills €480 paid
  over two weeks, nobody behind, pensions and benefit paid, the ledger balanced. The town
  gains money overall (wages €11–16k against €10–11k spent); balance is for T-0076.

## Questions

## Review feedback

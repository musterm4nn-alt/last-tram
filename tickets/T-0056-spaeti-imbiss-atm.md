---
id: T-0056
title: The Späti and the Imbiss sell food, an ATM, and Sunday closing
status: todo
milestone: M3
size: M
owner: builder
depends_on: [T-0055]
builder:
review_rounds: 0
---

## Goal
The two empty shops on the Altmarkt open for business. Späti Kaya gets a counter where you
can buy a snack (€2) or a beer (€1.50); Imbiss Anadolu gets a counter for a Döner (€6) or
fries (€3.50). A cash machine on the Altmarkt turns bank money into cash. And the town gets
Sunday closing: Café Wolke and the Waschsalon stay shut on Sundays, while the Späti, the
Imbiss and the Kneipe stay open.

## Read first
- `docs/design/jobs-and-economy.md` → Shops and services; T-0052 (how objects, interactions
  and placements were added); T-0055 (`Requirements`, prices).
- `data/objects/public.json`, `data/interactions/going_out.json`,
  `data/world/districts/altstadt/objects.json`, `sim/content/world_loader.gd`
  (`_read_access`), `sim/world/lot.gd`, `sim/world/lots.gd`.

## Scope
Create `data/objects/shops.json`, `data/interactions/shops.json`, `tests/sim/test_shops.gd`.
Change `sim/content/interaction_def.gd`, `sim/content/interaction_loader.gd`,
`sim/actions/requirements.gd`, `sim/systems/action_system.gd`, `sim/content/place_def.gd`,
`sim/content/world_loader.gd`, `sim/world/lot.gd`, `sim/world/lots.gd`,
`sim/save/save_validator.gd`, `data/world/districts/altstadt/district.json`,
`data/world/districts/altstadt/objects.json`, tests (`test_lots.gd`, `test_hud_place.gd`,
the broken-content fixture).
**Out of scope:** groceries and the fridge (T-0057), shop staff (T-0065), free will going
across town to eat (T-0057), a save version bump (not needed, see below).

## Specification

### Objects (`data/objects/shops.json`, same format as `public.json`)
| id | name | size | tags | use slots (offset → facing) |
|---|---|---|---|---|
| `spaeti_counter` | Späti counter | 3×1 | `spaeti_counter` | [0,1], [1,1], [2,1] → [0,-1] |
| `imbiss_counter` | Imbiss counter | 3×1 | `imbiss_counter` | [0,1], [1,1], [2,1] → [0,-1] |
| `atm` | Cash machine | 1×1 | `atm` | [1,0] → [-1,0] |
All block movement but not sight; prices (for build mode later) 150000, 250000, 1500000;
pick distinct `debug_color`s.

Placements (rotation 0, add to `objects.json` and its `_doc`): `spaeti_counter` at (3, 25, 0)
(customers stand at y 26, the space behind stays free for staff in T-0065), `imbiss_counter`
at (12, 25, 0), `atm` at (18, 25, 0) (on the Altmarkt against the Imbiss wall; the slot is
(19, 25)).

### Interactions (`data/interactions/shops.json`)
| id | name | tag | minutes | price | finish | advertise |
|---|---|---|---|---|---|---|
| `buy_snack` | Buy a snack | spaeti_counter | 5 | 200 | hunger +20 | hunger 20 |
| `grab_a_beer` | Have a Späti beer | spaeti_counter | 10 | 150 | fun +10 | fun 10 |
| `eat_doener` | Eat a Döner | imbiss_counter | 20 | 600 | hunger +60, moodlet `good_meal` | hunger 60 |
| `eat_fries` | Eat fries | imbiss_counter | 15 | 350 | hunger +35 | hunger 35 |
| `withdraw_20` | Withdraw €20 | atm | 2 | 0 | `cash_out` 2000 | none |
| `withdraw_50` | Withdraw €50 | atm | 2 | 0 | `cash_out` 5000 | none |

- `InteractionDef.cash_out: int = 0`: cents moved from the bank to cash when it finishes (the
  ATM). Loader: optional `"cash_out"` (`read_int`), error if < 0.
- `Requirements.check` gains a rule after the price: `"cant_afford"` if `def.cash_out > 0` and
  `person.wallet.bank < def.cash_out`.
- `ActionSystem._progress`, when an action finishes: `if def.cash_out > 0:
  Money.withdraw(sim, person, def.cash_out)` (a false return, because the bank emptied
  meanwhile, does nothing).
- An empty `advertise` scores 0, so free will never uses the ATM. That's intended: NPCs pay by
  card once their cash runs out.

### Closed days
- `district.json`: optional `"closed": ["sun"]` on a place with access "hours". Day names
  are `"mon"` … `"sun"`. Add it to `cafe_wolke` and `waschsalon_blitz`. Update the file's
  `_doc`.
- `PlaceDef.closed_days: PackedInt32Array` (0 = Monday … 6 = Sunday, like
  `SimClock.weekday()`). `WorldLoader._read_access` reads it. Errors: `"closed" only applies
  to access "hours"`, and `unknown day 'funday' in "closed"`.
- `Lot.closed_days: PackedInt32Array`, copied in `from_place`, saved as `"closed_days"` (a
  list of ints). `from_dict` reads `d.get("closed_days", [])`, so old saves load: their lots
  keep no closed days, which is fine. `SaveValidator` checks it is a list of integers 0..6
  when present.
- `Lots.is_open`: an "hours" lot is closed all day on its closed days, checked before the
  hours. Days are calendar days, so a place open past midnight would close at midnight
  before a closed day (none does today); write that in the doc comment.
- The HUD already shows "(closed)" through `Lots.is_open`, and T-0055's requirements already
  refuse a closed place, so nothing else changes.

## Acceptance criteria
- [ ] Content → `test_shops.gd::test_shop_content_loads_and_every_counter_can_be_reached`
  (the six interactions with their prices; a route exists from the Altmarkt (20, 27, 0) to a
  free slot of each counter and of the ATM). Broken fixture: `closed` on a public place and an
  unknown day name are reported (`test_content.gd`).
- [ ] `test_a_doener_fills_you_up` (player at the Imbiss counter at Monday 12:00 with hunger
  30: after `eat_doener`, hunger ≥ 85, €6 less, the `good_meal` moodlet).
- [ ] `test_the_atm_turns_bank_money_into_cash` (+€20 cash, −€20 bank, the ledger unchanged)
  and `test_the_atm_needs_money_in_the_bank` (bank €10 → refused, `cant_afford`).
- [ ] Sunday → `test_cafe_and_waschsalon_close_on_sunday` (`Lots.is_open` is false on
  Sunday 12:00 and true on Monday 12:00; the Späti, Imbiss and Kneipe are open on Sunday in
  their hours) and `test_no_coffee_on_sunday` (refused with `closed`).
- [ ] Saving → `test_lots.gd`: closed days round-trip through a save, and the v3 fixture
  loads with no closed days.
- [ ] HUD → `test_hud_place.gd`: "Café Wolke (closed)" on Sunday at 12:00.
- [ ] `tools/check.sh` passes; `tools/simrun.sh --days=7 --check-m2` still passes. Screenshot
  `out/t0056.png` (`--interact=imbiss_counter`, with the player walked to the Imbiss) shows
  both counters, the ATM and the priced menu. Look at it.

## Implementation notes

## Questions

## Review feedback

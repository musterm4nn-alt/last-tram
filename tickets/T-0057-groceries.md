---
id: T-0057
title: Groceries - the fridge can run empty
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0056]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Food at home stops being free. Each household's fridge holds groceries, counted in portions:
cooking a meal uses two and a snack uses one. When the fridge is empty you can't cook, so you
buy a bag of groceries at the Späti (€9 for 6 portions) or eat out. Residents go shopping on
their own when their fridge runs low, and eat at the Imbiss or the Späti when they're hungry
and the fridge is empty.

## Read first
`docs/design/jobs-and-economy.md` → Groceries; D29 (groceries are the only items in M3);
`sim/actions/requirements.gd`, `sim/systems/action_system.gd` (`_start_performing`,
`_progress`), `sim/ai/autonomy.gd` (`candidates`, `_outing_objects`),
`sim/people/household.gd`, `tools/town_check.gd` (`EATING`), `game/ui/interaction_menu.gd`.

## Scope
Create `sim/economy/groceries.gd`, `tests/sim/test_groceries.gd`,
`tests/fixtures/saves/v5_basic.json`.
Change `data/economy.json`, `sim/content/economy_def.gd`, `economy_loader.gd`,
`sim/content/interaction_def.gd`, `interaction_loader.gd`, `data/interactions/basics.json`,
`home.json`, `shops.json`, `sim/people/household.gd`, `sim/sim_factory.gd`,
`sim/actions/requirements.gd`, `sim/systems/action_system.gd`, `sim/ai/autonomy.gd`,
`sim/save/save_codec.gd`, `save_migrations.gd`, `save_validator.gd`,
`game/ui/interaction_menu.gd`, `tools/town_check.gd`, `tools/sim_runner.gd`.
**Out of scope:** a personal inventory (M4), shop staff (T-0065), spoiling food.

## Specification

### Data
- `economy.json` (with `EconomyDef` fields, validated): `"fridge_capacity": 20`,
  `"start_groceries": [6, 14]`, `"restock_below": 4`, `"restock_bonus": 4.0`,
  `"hungry_below": 40`.
- `InteractionDef.uses_groceries: int` (portions taken when it starts, from the household
  whose home lot the target object stands on) and `adds_groceries: int` (portions added to the
  actor's household when it finishes). Both optional, ≥ 0.
- `cook_meal` `"uses_groceries": 2`, `grab_snack` `"uses_groceries": 1`. New in `shops.json`:
  `buy_groceries` ("Buy groceries", `spaeti_counter`, 5 min, price 900, `"adds_groceries": 6`,
  advertise hunger 30).

### State: `Household.groceries: int` (portions), saved
- **Save v5.** `_v4_to_v5`: every household gets 10 portions. `SaveValidator`: `groceries` is
  an integer ≥ 0 when present. Fixture `v5_basic.json`. Fix `Household`'s doc comment (it still
  says households share money from M3; D29).
- New games: `Groceries.give_start(sim)` after `Money.give_start`: each household, in id
  order, gets `randi_range(start min, max)` portions from `sim.rng.stream("groceries")`.

### `Groceries` (`sim/economy/groceries.gd`, static)
- `household_at(sim, obj: WorldObject) -> Household`: the household whose `home_lot_id` is
  the lot under the object's origin (null for none).
- `home_household(sim, person) -> Household`: the person's household if it has a home lot.
- `stock_text(sim, obj) -> String`: `"6 portions"` (or "1 portion"), "" when the object isn't
  in a home.

### Rules
- `Requirements.check`, after the price rules: `"no_food"` ("the fridge is empty") when
  `uses_groceries > 0` and the object's household has fewer portions; `"no_home"` ("no
  home") when `adds_groceries > 0` and the actor has no home household; `"fridge_full"` ("the
  fridge is full") when the stock + `adds_groceries` > `fridge_capacity`.
- `ActionSystem._start_performing`: after paying, take `uses_groceries`. When it finishes
  (`_progress`), add `adds_groceries` to the actor's home household (capped at capacity).
  Emit `groceries_changed {household_id, groceries}` for both.
- **Errands in free will.** `Autonomy.candidates` counts far objects (any distance or level,
  like "out" objects) for these interactions, and only these:
  - `adds_groceries > 0` while the person's household has fewer than `restock_below`
    portions; their score gets `+ restock_bonus`. Near or far, a grocery run is a candidate
    only while the stock is low (no hoarding).
  - Food for sale (`price > 0` and advertises hunger) while hunger < `hungry_below` and the
    home has fewer than 2 portions.
  Far candidates use the first reachable free slot, as "out" objects do.
- **Menu header:** an object in a home whose interactions use groceries shows the stock:
  `"Fridge · 6 portions"`.
- `TownCheck.EATING` also counts `eat_doener`, `eat_fries` and `buy_snack`. The simrun
  report adds `groceries: households hold N portions (lowest M), bags bought K`.

## Acceptance criteria
- [x] `test_groceries.gd::test_cooking_uses_portions` (cook −2, snack −1) and
  `test_an_empty_fridge_greys_out_cooking` (refused `no_food`; menu "… (the fridge is
  empty)").
- [x] `test_buying_groceries_fills_the_fridge` (+6 at home, −€9) and
  `test_a_full_fridge_refuses_more`.
- [x] Free will → `test_low_stock_sends_people_shopping` (a resident with 2 portions at home
  gets a `buy_groceries` option at the Späti from across town; with 12 they don't) and
  `test_hungry_people_with_empty_fridges_eat_out`.
- [x] Saving → v5 round trip, the migration gives 10 portions, starting stock is
  deterministic and within the range.
- [x] `tools/check.sh` passes. `tools/simrun.sh --days=7 --check-m2` passes on seeds 1–3 (so
  everyone still eats); the notes give bags bought, Döner and snacks eaten, and the lowest
  stock.

## Implementation notes
- As specified: `Groceries` (`sim/economy/groceries.gd`), `Household.groceries` (save v5,
  `_v4_to_v5`, the validator, `v5_basic.json`), `uses_groceries`/`adds_groceries`, the
  `no_food`/`no_home`/`fridge_full` requirements, errands in `Autonomy.candidates`
  (`Autonomy.errand`), the fridge's menu header, `TownCheck.EATING`, the simrun groceries line.
- One addition: objects on **no lot** (only in `from_rows` test rooms) aren't limited by
  groceries (`Groceries.counts`), as they already pass the lot rules. Without it, every test
  room's fridge counted as empty. In the real town every fridge is in a home.
- Built in a second worktree while Muse playtested T-0054..56 in the first.
- Verified: `tools/check.sh` 508 passed, 0 failed (`test_groceries.gd`, 8 tests, and a
  validation test). `tools/simrun.sh --days=7 --check-m2` PASSED on seeds 1, 2 and 3:
  residents bought 121/122/105 bags of groceries a week, plus 63/53/63 Späti snacks,
  16/19/10 Döner and 20/15/23 fries. The lowest resident hunger was 16.3/14.9/18.8 (under 30
  for 0.6/0.8/0.3% of minutes), and households ended the week with 27/35/45 portions. Residents
  spent €3,490/€3,311/€3,075 in a week (food and drinks). Screenshot `out/t0057.png`: "Fridge
  · 11 portions".

## Questions

## Review feedback

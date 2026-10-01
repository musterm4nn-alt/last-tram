---
id: T-0055
title: Prices, and one check for what a person may do now
status: todo
milestone: M3
size: M
owner: builder
depends_on: [T-0054]
builder:
review_rounds: 0
---

## Goal
Things start to cost money: a drink at the Kneipe costs €4 and a coffee at Café Wolke €3, paid
when you start. One shared check decides whether a person may start an interaction now, and
gives the reason if not: the place is closed, it's someone else's home, or you can't afford
it. The menu shows prices and greys out what you can't do ("Have a drink · €4.00 (closed)"),
a refused order says why, and free will skips what people can't afford and spends a little
less freely when money is short.

## Read first
- `docs/decisions.md` D29, `docs/design/jobs-and-economy.md` → "What a person may do".
- `sim/commands/queue_interaction_command.gd`, `sim/systems/action_system.gd`
  (`_start_performing`), `sim/ai/autonomy.gd` (`candidates`), `sim/ai/utility.gd`,
  `game/ui/interaction_menu.gd`, `game/ui/hud.gd` (`notice_for_event`), `sim/world/lots.gd`.

## Scope
Create `sim/actions/requirements.gd`, `tests/sim/test_prices.gd`.
Change `sim/content/interaction_def.gd`, `sim/content/interaction_loader.gd`,
`sim/content/economy_def.gd`, `sim/content/economy_loader.gd`, `data/economy.json`,
`data/interactions/going_out.json`, `sim/commands/queue_interaction_command.gd`,
`sim/systems/action_system.gd`, `sim/ai/autonomy.gd`, `sim/ai/utility.gd`,
`game/ui/interaction_menu.gd`, `game/ui/hud.gd`, and tests:
`tests/game/test_interaction_menu.gd`, `tests/game/test_hud_place.gd` (or the file that
already tests `notice_for_event`), a broken interaction in
`tests/fixtures/content_broken/interactions/`.
**Out of scope:** new shops and food (T-0056), groceries (T-0057), opening hours by weekday
(T-0056), anything about jobs.

## Specification

### Data
- `InteractionDef.price: int = 0`: what it costs in euro cents, paid when it starts
  performing (0 = free). `InteractionLoader`: optional `"price"` via `reader.read_int`;
  errors: `'price' must be >= 0`, and `person-targeted interactions are free` when a
  `target: "person"` interaction has a price.
- `going_out.json`: `have_a_drink` `"price": 400`, `have_a_coffee` `"price": 300`
  (`sit_outside` stays free).
- `economy.json` gains three tuning numbers (and `EconomyDef` gets the fields, validated ≥ 0):
  `"price_cost_per_euro": 0.3` (float), `"low_money": 5000` (int, cents),
  `"low_money_factor": 3.0` (float).

### `Requirements` (`sim/actions/requirements.gd`, static, no state)
```gdscript
class_name Requirements
extends RefCounted
## Whether a person may start an interaction now (D29): "" when they may, otherwise the
## reason. The interaction menu, QueueInteractionCommand, free will and ActionSystem all ask
## here, so a rule added once applies everywhere. Later tickets add rules (no_food,
## not_staffed, not_your_shift, unknown_secret...).

## Words for each reason, for menus and notices.
const TEXT: Dictionary = {"closed": "closed", "private": "not your home", "cant_afford": "not enough money"}

static func check(sim: Sim, person: Person, def: InteractionDef, target_id: int) -> String
static func text(reason: String) -> String   # TEXT, else the id with "_" → " "
```
`check`, in this order:
1. For `def.target == "object"`: the lot under the target object's origin
   (`Lots.lot_at`). `"closed"` if `lot.access == Lot.HOURS` and `not Lots.is_open(lot,
   sim.clock)`. `"private"` if `lot.access == Lot.PRIVATE` and `person.home_lot_id != lot.id`.
   Objects on no lot (test rooms) pass.
2. `"cant_afford"` if `def.price > 0` and `not Money.can_afford(person, def.price)`.
3. Otherwise `""`.

### Where it is used
- **`QueueInteractionCommand.apply`**: after the existing "offered" check, if
  `Requirements.check` gives a reason, nothing is queued and it emits
  `&"action_refused" {person_id, interaction_id, target_id, reason}`.
- **`ActionSystem._start_performing`** (first thing): if `Requirements.check` gives a reason,
  `_fail(sim, person, action, reason)`. Otherwise, if `def.price > 0`,
  `Money.spend(sim, person, def.price, "purchase", def.id)` (a false return fails it with
  `"cant_afford"`). A PERFORMING action has been paid, so loading a save never charges twice.
- **`Autonomy.candidates`**: inside the per-interaction loop, skip options whose check isn't
  "", and subtract `Utility.price_cost(person, def, sim.content)` from the score (the existing
  `Lots.may_enter` pre-filter per object stays, as it saves path searches).
  `_person_options` is unchanged (social interactions are free).
- **`Utility.price_cost(person: Person, def: InteractionDef, content: ContentDB) -> float`**:
  0 for free interactions, else `price / 100.0 × price_cost_per_euro`, times
  `low_money_factor` when `person.wallet.total() < low_money`. (A €4 drink costs 1.2 points of
  score, or 3.6 when you have under €50; the going-out bonus is 5.)
- **`InteractionMenu`**: a new pure `static func label(sim, person, def, target_id) -> String`
  gives `name`, then `" · €4.00"` when it has a price, then `" (reason text)"` when the check
  fails. `entries()` uses it with the player. `prepare()` disables the items whose check fails
  (`set_item_disabled`).
- **`Hud.notice_for_event`**: `action_refused` for the player gives the same kind of notice as
  `action_failed`, `"Have a drink: not enough money"`. Both events get words for the reasons
  in `FAIL_REASONS` and in `Requirements.TEXT`. Other reasons still show nothing.

## Acceptance criteria
- [ ] Content → `test_prices.gd::test_prices_load` (drink 400, coffee 300, sit outside 0);
  the broken fixture's negative price and priced social interaction are reported
  (`test_content.gd`).
- [ ] Paying → `test_prices.gd::test_a_drink_is_paid_when_it_starts` (new game, Monday 20:00,
  the player next to the Kneipe's bar counter: after it starts, €4 less,
  `ledger.sinks["purchase"] == 400`, one `money_changed` with reason "purchase"; a save while
  it performs and a load don't charge again).
- [ ] Refusals → `test_cannot_queue_what_you_cannot_afford` (€2: refused with `cant_afford`,
  nothing queued, money unchanged), `test_closed_place_refuses` (the bar at 10:00 →
  `closed`), `test_someone_elses_fridge_is_private` (a neighbour's fridge → `private`).
- [ ] `test_money_gone_on_the_way_fails_at_the_start`: queued while affordable, money spent
  before arrival → `action_failed` with `cant_afford`, nothing charged.
- [ ] Free will → `test_free_will_skips_what_it_cannot_afford` (a resident with €0 in their
  out window gets no drink or coffee option; with money they do) and
  `test_price_cost_grows_when_money_is_short` (exact values 1.2 and 3.6 for €4).
- [ ] Menu → `test_interaction_menu.gd::test_menu_shows_prices_and_reasons`
  ("Have a drink · €4.00" when open and affordable; "… (closed)" at 10:00 and disabled in
  `prepare()`; "… (not enough money)" with an empty wallet).
- [ ] Notice → `"Have a drink: not enough money"` for a refused order (HUD test).
- [ ] Existing tests that queued things at a closed place or in someone else's home are
  moved to the right time or home, not loosened (list them in the notes).
- [ ] `tools/check.sh` passes; `tools/simrun.sh --days=7 --check-m2` still passes, and its
  money line shows purchases. Screenshot `out/t0055.png`
  (`--interact=bar_counter`, Monday 08:00) shows the greyed-out "(closed)" entry.

## Implementation notes

## Questions

## Review feedback

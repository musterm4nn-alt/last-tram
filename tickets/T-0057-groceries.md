---
id: T-0057
title: Groceries - the fridge can run empty
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0056]
builder:
review_rounds: 0
---

## Goal
Food at home stops being free. Each household's fridge holds groceries, counted in portions:
cooking a meal uses two and a snack uses one. When the fridge is empty you can't cook, so you
buy a bag of groceries at the Späti (€9 for 6 portions) or eat out. Residents go shopping on
their own when their fridge runs low, and eat at the Imbiss when they're hungry and the fridge
is empty.

## Read first
`docs/design/jobs-and-economy.md` → Groceries; D29 (groceries are the only items in M3);
T-0055 (`Requirements`), T-0056 (shop counters); `sim/ai/autonomy.gd` (far "out" objects);
`tools/town_check.gd` (`EATING`).

## Design (draft: detailed when its dependencies are merged)
- `Household.groceries: int` (portions), saved. **Save v5**: the migration gives every
  household 10 portions. Also update `Household`'s doc comment (it still says households
  share money).
- `economy.json`: `fridge_capacity` 20, `start_groceries` [6, 14] (drawn from the "money"
  stream at new game), `restock_below` 4, `restock_bonus`, `hungry_below` 40.
- `InteractionDef.uses_groceries: int`: portions taken when it starts, from the household
  whose home lot the target object stands on. `adds_groceries: int`: portions added to the
  actor's household when it finishes.
- `Requirements`: `no_food` ("the fridge is empty") when that household has too few portions;
  `fridge_full` when the actor's household can't fit the bag; `no_home` when the actor has no
  household home.
- Data: `cook_meal` uses 2, `grab_snack` uses 1; a new `buy_groceries` ("Buy groceries", Späti
  counter, 5 min, €9, adds 6).
- **Errands in free will** (`Autonomy.candidates`): like "out" objects, these count anywhere in
  town. `buy_groceries` counts (with `restock_bonus`) when the household's stock is below
  `restock_below`, and only then. Food for sale (a price, advertises hunger) counts when hunger
  is below `hungry_below` and the home has fewer than 2 portions.
- The interaction menu's header for a fridge shows the stock: "Fridge · 6 portions".
- `TownCheck.EATING` includes the shop foods (a Döner is a meal).

## Acceptance (sketch)
- Cooking uses portions; an empty fridge greys cooking out with "the fridge is empty";
  buying adds 6 and costs €9; a full fridge refuses.
- Free will: a household with 2 portions goes shopping; one with 12 doesn't.
- 7-day run: `--check-m2` still passes (everyone still eats); simrun reports groceries
  bought, Döner and snacks eaten, and money spent on food. Save v5 fixture and migration.

## Implementation notes

## Questions

## Review feedback

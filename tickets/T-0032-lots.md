---
id: T-0032
title: Lots - places become owned areas with access rules and opening hours
status: todo
milestone: M2
size: M
owner: builder
depends_on: []
builder:
review_rounds: 0
---

## Goal
Every place becomes a **lot** in the world: public (squares, streets, the park), open during
opening hours (the Späti, the Kneipe, the café), or private (homes). People know which lot is
their home. Free will only uses objects on lots the person may enter, so nobody wanders into
someone else's flat to cook. (Residents, households and trespassing come later: T-0034, M4.)

## Read first
- `docs/design/world-and-map.md` → "Places, lots and rooms"
- As merged: `sim/content/place_def.gd`, `sim/content/world_loader.gd` (places),
  `data/world/districts/altstadt/district.json`, `sim/world/world.gd` (entities by id,
  saving), `sim/sim_factory.gd`, `sim/ai/autonomy.gd` (`candidates`)

## Scope
Change `sim/content/place_def.gd`, `sim/content/world_loader.gd`,
`data/world/districts/altstadt/district.json` (hours on the businesses), `sim/world/world.gd`,
`sim/people/person.gd` (`home_lot_id`), `sim/sim_factory.gd`, `sim/ai/autonomy.gd`,
`game/ui/hud.gd` (the place line says "closed" when it is). Create `sim/world/lot.gd` (`Lot`),
`sim/world/lots.gd` (`Lots`), `tests/sim/test_lots.gd`.
**Out of scope:** rent and money (M3), trespassing (M4), households (T-0034).

## Specification
- Places gain optional `"access"`: `"public"`, `"private"` or `"hours"` (with required
  `"hours": [open_hour, close_hour]`, 0..24; close < open means past midnight). Defaults by
  kind: `home` → private; `shop`, `cafe`, `bar`, `restaurant` → must say `"hours"`; everything
  else → public. Validated.
- `Lot` (entity, saved in `World.lots: Dictionary[int, Lot]`): `id`, `place_id`, `access`,
  `open_hour`, `close_hour`. `SimFactory.new_game` creates one lot per place (in place order).
  Loading keeps lots from the save; places missing from content are dropped quietly.
- `Person.home_lot_id: int` (saved, default 0). The new-game player gets the lot of place
  `home_player`.
- `Lots` (static): `lot_at(sim, cell) -> Lot` (the place `ContentDB.place_at` finds, or null),
  `is_open(lot, clock) -> bool`, `may_enter(sim, person, lot) -> bool` (public → yes; hours →
  open now; private → `person.home_lot_id == lot.id`).
- `Autonomy.candidates` skips objects whose origin's lot the person may not enter (objects on
  no lot count as public).
- HUD place line: "Späti Kaya (closed)" while an hours lot is closed.

## Acceptance criteria (`tests/sim/test_lots.gd`)
- [ ] A new game has one lot per place, with the right access (the player's flat private,
  the Späti by hours, the Altmarkt public); the player's `home_lot_id` is their flat.
- [ ] `is_open` for normal and past-midnight hours (e.g. 18–2 open at 01:00, closed at 03:00).
- [ ] `may_enter`: public always; hours only when open; private only for its residents.
- [ ] Free will ignores a fridge placed in someone else's (private) flat but uses one in the
  player's flat.
- [ ] Lots and `home_lot_id` survive save/load; a save without lots gets them from content.
- [ ] Content validation rejects an unknown access value and "hours" without hours.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback

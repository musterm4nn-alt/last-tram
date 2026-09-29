---
id: T-0034
title: Residents and households: about 30 generated neighbours with homes
status: draft
milestone: M2
size: L
owner: builder
depends_on: [T-0031, T-0033]
builder:
review_rounds: 0
---

## Goal
A new game fills the flats with generated adults: singles, couples and flatmates (households), each with a name, look, outfit and personality from the same model as the player, living in a home lot.

## Notes for the architect (to detail before this becomes todo)
- `sim/people/household.gd` (`Household`: id, member ids, home lot id), `World.households`, `Person.household_id`; private lots admit their household (update `Lots.may_enter`).
- `sim/people/generator.gd`: deterministic from the world seed (rng stream "generation"); ages 18+ (test every person), couples share a double bed flat.
- Everyone spawns at home; the player's household is only the player.

## Implementation notes

## Questions

## Review feedback

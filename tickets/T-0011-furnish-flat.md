---
id: T-0011
title: Furnish the player's flat (objects and interactions content)
status: draft
milestone: M1
size: S
owner: builder
depends_on: [T-0006]
builder:
review_rounds: 0
---

## Goal
The flat in Haus 12 has everything for a day at home: bed, fridge, stove, shower, sink, sofa, TV, table and chairs, with their interactions (sleep, nap, grab snack, cook, shower, wash hands, sit, watch TV, eat at table). No toilet: there is no bladder need (D21).

## Notes for the architect (to detail before this becomes todo)
- Mostly data: `data/objects/*.json`, `data/interactions/*.json`, `altstadt/objects.json`.
- Cooking: 30 min at the stove → +60 hunger at the end; it should beat snacks for autonomy.
- The shower needs privacy (the field arrives with rooms in M2; leave a TODO note in the ticket, not in code).
- Check every object is reachable (a test: every placed object has at least one reachable slot from the player's spawn).

## Implementation notes

## Questions

## Review feedback

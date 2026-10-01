---
id: T-0035
title: Neighbours live by free will
status: draft
milestone: M2
size: M
owner: builder
depends_on: [T-0034]
builder:
review_rounds: 0
---

## Goal
Every resident uses the same autonomy as the player: they eat, sleep, wash and relax at home, and use public places. No NPC-specific code paths.

## Notes for the architect (to detail before this becomes todo)
- T-0034 already cut the cost (D27: retry back-off, per-minute slot checks, place index): 0.055 ms per step with 25 residents. AutonomySystem already loops over all people; re-check cost with 30 people (pathfinding per candidate may need caching: nearest-slot distance estimate first, real path only for the top options).
- Persons never share a slot (T-0007 reservations) – add a 30-person property test.

## Implementation notes

## Questions

## Review feedback

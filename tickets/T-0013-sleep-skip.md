---
id: T-0013
title: Fast-forward while sleeping
status: draft
milestone: M1
size: S
owner: builder
depends_on: [T-0006]
builder:
review_rounds: 0
---

## Goal
While the player sleeps, time automatically runs much faster until they wake up or something important happens.

## Notes for the architect (to detail before this becomes todo)
- game/ only (Session speed logic): a 'skip' speed (e.g. 30x) while the player's front action is sleep; return to the previous speed on finish, cancel or a need_critical event.
- Max steps per frame must keep the UI responsive; HUD shows '▶▶ skipping'.

## Implementation notes

## Questions

## Review feedback

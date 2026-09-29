---
id: T-0036
title: Daily routines: sleep at night, go out in the evening
status: draft
milestone: M2
size: M
owner: builder
depends_on: [T-0035]
builder:
review_rounds: 0
---

## Goal
People keep a rhythm: sleep windows (a night owl sleeps late), mornings at home, evenings at the Kneipe, the café or the park depending on personality. Fixes the M1 'naps at noon' issue for the player too.

## Notes for the architect (to detail before this becomes todo)
- Routine templates in data (`data/routines/*.json`): sleep window, preferred place kinds by time block.
- Scoring bonus/penalty by time of day and routine (e.g. sleep advertised ×2 inside the sleep window, ×0.3 outside); travel to another lot as an interaction ('go to <place>').
- Opening hours matter (T-0032).

## Implementation notes

## Questions

## Review feedback

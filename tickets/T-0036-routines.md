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
- Seen in T-0032's screenshot: free will only searches `Autonomy.SEARCH_RADIUS` (12) cells,
  so a person left idle far from home (the player at the Späti) never goes home and their
  needs run down to zero. Routines must include "go home" when nothing useful is in reach,
  and an acceptance test should leave someone idle across town for a day.

## Implementation notes

## Questions

## Review feedback
